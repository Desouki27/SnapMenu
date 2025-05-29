# multi_tool_agent/agent.py

from dotenv import load_dotenv
load_dotenv()

import os
import base64
import logging
import requests
import io
from urllib.parse import urlparse, urljoin # For making relative URLs absolute

import google.generativeai as genai
from google.adk.agents import Agent
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
import httpx
from bs4 import BeautifulSoup # For HTML parsing

# ─── configure your logger ─────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)

# ─── Tool 1: OCR via Vision API with LLM Filtering ─────────────────────────────
def detect_menu(image_b64: str) -> dict:
    try:
        vision_key = os.getenv("VISION_API_KEY")
        if not vision_key:
            raise RuntimeError("VISION_API_KEY not set in environment")
        ocr_url = f"https://vision.googleapis.com/v1/images:annotate?key={vision_key}"
        ocr_payload = {
            "requests": [{"image": {"content": image_b64},"features": [{"type": "TEXT_DETECTION", "maxResults": 1}]}]
        }
        resp_ocr = requests.post(ocr_url, json=ocr_payload, timeout=15)
        resp_ocr.raise_for_status()
        data_ocr = resp_ocr.json()
        raw_ocr_text = data_ocr["responses"][0].get("textAnnotations", [{}])[0].get("description", "")
        if not raw_ocr_text.strip():
            logger.info("detect_menu → no text found by OCR")
            return {"status": "success", "items": []}
        logger.info("detect_menu → OCR extracted %d characters", len(raw_ocr_text))

        gemini_key = os.getenv("GEMINI_API_KEY")
        if not gemini_key:
            logger.warning("GEMINI_API_KEY not set → returning raw OCR lines without filtering")
            raw_items = [l.strip() for l in raw_ocr_text.split("\n") if l.strip()]
            return {"status": "success_ocr_only","items": raw_items,"message": "LLM filtering skipped"}

        genai.configure(api_key=gemini_key)
        llm = genai.GenerativeModel("gemini-1.5-flash-latest")
        prompt = f"""Analyze the following text extracted from a restaurant menu. Your task:
1) Extract only the dish/item names customers can order.
2) Exclude section headers, descriptions, prices, codes, general info, etc.
3) Return each dish name on its own line, no preamble.
Menu Text:\n---\n{raw_ocr_text}\n---\nDish Names:"""
        logger.info("detect_menu → sending to Gemini for filtering")
        cfg = genai.types.GenerationConfig(temperature=0.1)
        resp_llm = llm.generate_content(prompt, generation_config=cfg)

        if resp_llm.prompt_feedback and resp_llm.prompt_feedback.block_reason:
            reason = resp_llm.prompt_feedback.block_reason_message or "safety filter"
            logger.error("Gemini blocked (detect_menu filtering): %s", reason)
            return {"status": "error", "message": f"LLM content generation blocked: {reason}"}

        filtered_items = []
        text_out = ""
        try:
            text_out = resp_llm.text
            filtered_items = [l.strip() for l in text_out.split("\n") if l.strip()]
        except ValueError:
            logger.warning("Gemini response.text failed (detect_menu filtering). Parts: %s", resp_llm.parts if hasattr(resp_llm, 'parts') else "N/A")
            if not (resp_llm.prompt_feedback and resp_llm.prompt_feedback.block_reason):
                 return {"status": "error", "message": "LLM response parsing failed (detect_menu filtering) and not blocked by safety."}
        
        logger.info("detect_menu → LLM returned %d items", len(filtered_items))
        return {"status": "success", "items": filtered_items}
    except requests.RequestException as re:
        logger.exception("detect_menu network error")
        return {"status": "error", "message": f"Network error: {re}"}
    except Exception as e:
        logger.exception("detect_menu failed")
        return {"status": "error", "message": str(e)}

# ─── Tool 2: image lookup via Custom Search ──────────────────────────────────
def search_image(dish: str) -> dict:
    try:
        cse_key = os.getenv("CSE_API_KEY")
        cse_cx = os.getenv("CSE_CX")
        gemini_key = os.getenv("GEMINI_API_KEY")
        if not cse_key or not cse_cx:
            raise RuntimeError("CSE_API_KEY or CSE_CX not set in environment for image search.")

        search_term_for_cse = f"{dish} meal photo"
        if gemini_key:
            try:
                genai.configure(api_key=gemini_key)
                query_gen_model_name = 'gemini-1.5-flash-latest'
                model = genai.GenerativeModel(query_gen_model_name)
                query_generation_prompt = f"""Given the menu item name "{dish}", generate an effective Google image search query as a series of keywords.
The query should be designed to find a high-quality photograph of this dish as a prepared meal, ready to be served and eaten.
Focus on terms that emphasize the final plated dish. Example keywords: plated, dish, meal, food photography, restaurant style.
Return only the keywords, separated by spaces. Do not enclose the entire query in quotes or add any other explanations.
Menu Item: "{dish}"\nEffective Image Search Keywords:"""
                logger.info(f"Generating CSE query with Gemini ('{query_gen_model_name}') for dish: '{dish}'")
                query_gen_config = genai.types.GenerationConfig(temperature=0.2, candidate_count=1)
                response_query_gen = model.generate_content(query_generation_prompt, generation_config=query_gen_config)
                generated_query_raw = ""
                if response_query_gen.prompt_feedback and response_query_gen.prompt_feedback.block_reason:
                    reason = response_query_gen.prompt_feedback.block_reason_message or "safety filter"
                    logger.error(f"Gemini query generation blocked: {reason}. Using fallback for '{dish}'.")
                else:
                    try:
                        generated_query_raw = response_query_gen.text.strip()
                    except ValueError:
                        logger.warning(f"Gemini .text failed for query gen for '{dish}'. Fallback. Parts: %s", response_query_gen.parts if hasattr(response_query_gen, 'parts') else "N/A")
                
                if generated_query_raw:
                    temp_query = generated_query_raw
                    if temp_query.startswith('"') and temp_query.endswith('"'): temp_query = temp_query[1:-1].strip()
                    elif temp_query.startswith("'") and temp_query.endswith("'"): temp_query = temp_query[1:-1].strip()
                    if temp_query: search_term_for_cse = temp_query; logger.info(f"Gemini processed query: '{search_term_for_cse}' for '{dish}'")
                    else: logger.warning(f"LLM query for '{dish}' empty after strip. Fallback.")
                else: logger.warning(f"Gemini empty query or .text fail for '{dish}'. Fallback.")
            except Exception as llm_e:
                logger.exception(f"LLM query gen failed for '{dish}'. Fallback. Error: {llm_e}")
        else:
            logger.warning(f"GEMINI_API_KEY not set. Fallback query '{search_term_for_cse}' for '{dish}'.")

        q = requests.utils.requote_uri(search_term_for_cse)
        api_url = f"https://www.googleapis.com/customsearch/v1?key={cse_key}&cx={cse_cx}&searchType=image&imgType=photo&num=1&q={q}"
        logger.info(f"Searching CSE: '{search_term_for_cse}' (Original: '{dish}')")
        resp = requests.get(api_url, timeout=10)
        resp.raise_for_status()
        data = resp.json(); items = data.get("items", [])
        image_url = items[0].get("link") if items else (items[0].get("image", {}).get("thumbnailLink") if items else None)
        if items and not image_url: # Secondary check for other link types if primary 'link' fails
             if items[0].get("pagemap") and items[0]["pagemap"].get("cse_image"):
                 try: image_url = items[0]["pagemap"]["cse_image"][0].get("src")
                 except: pass

        if image_url: logger.info("search_image ('%s' as '%s') → URL: %s", dish,search_term_for_cse,image_url)
        else: logger.warning("search_image ('%s' as '%s') → No URL found.", dish,search_term_for_cse)
        return {"status": "success", "url": image_url}
    except requests.RequestException as re:
        logger.exception("search_image network error for '%s'", dish); return {"status": "error", "message": f"Network error: {re}"}
    except Exception as e:
        logger.exception("search_image failed for '%s'", dish); return {"status": "error", "message": str(e)}

# ─── Compose into an ADK Agent ────────────────────────────────────────────────
root_agent = Agent(name="menu_analyzer",model="gemini-2.0-flash",description="Extracts menu items and fetches dish images.",
    instruction="Tool `detect_menu(image_b64)` → {items:[]}. Tool `search_image(dish)` → {url:dish_image_url}.",
    tools=[detect_menu, search_image])

# ─── Standalone FastAPI app ──────────────────────────────────────────────────
app = FastAPI(title="Menu Analyzer Agent")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.post("/upload_menu/")
async def upload_menu(file: UploadFile = File(...)):
    try:
        content = await file.read(); b64 = base64.b64encode(content).decode(); result = detect_menu(b64)
        if result.get("status","")=="error": msg=result.get("message","Error in detect_menu"); logger.error("upload_menu → %s",msg); raise HTTPException(500,msg)
        return result
    except HTTPException: raise
    except Exception as e: logger.exception("❌ /upload_menu/ failed"); raise HTTPException(500,str(e))

@app.post("/get_dish_image/")
async def get_dish_image(body: dict):
    try:
        dish = body.get("dish")
        if not dish or not isinstance(dish,str) or not dish.strip(): raise HTTPException(400,"Valid 'dish' string required.")
        result = search_image(dish.strip())
        if result.get("status")=="error": msg=result.get("message","Error in search_image"); logger.error("get_dish_image → %s",msg); raise HTTPException(500,msg)
        return result
    except HTTPException: raise
    except Exception as e: logger.exception("❌ /get_dish_image/ failed"); raise HTTPException(500,str(e))

async def fetch_and_stream_image_content(actual_image_url: str, client: httpx.AsyncClient, original_url_for_logging: str):
    """Helper: Fetches a direct image URL and prepares it for streaming."""
    logger.info(f"Proxy: Attempting direct image fetch from: {actual_image_url} (for original: {original_url_for_logging})")
    img_response = await client.get(actual_image_url) # Headers are from the client instance
    
    img_content_type = img_response.headers.get("content-type", "unknown").lower()
    logger.info(f"Proxy: Direct image fetch from {actual_image_url} - Status: {img_response.status_code}, Content-Type: {img_content_type}")
    
    img_response.raise_for_status()

    if not img_content_type.startswith("image/"):
        logger.error(f"Proxy: Extracted URL {actual_image_url} is not an image. Content-Type: {img_content_type}")
        raise HTTPException(status_code=415, detail=f"Unsupported Media Type from extracted URL: {img_content_type}")
    
    return StreamingResponse(io.BytesIO(img_response.content), media_type=img_content_type)

@app.get("/proxy_image/")
async def proxy_image(image_url: str):
    if not image_url:
        raise HTTPException(status_code=400, detail="image_url query parameter is required.")

    request_headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.71 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
        "Accept-Language": "en-US,en;q=0.9",
    }

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True, headers=request_headers) as client:
        try:
            logger.info(f"Proxy: Initial fetch for: {image_url}")
            initial_response = await client.get(image_url)
            
            initial_status = initial_response.status_code
            initial_content_type = initial_response.headers.get("content-type", "unknown").lower()
            logger.info(f"Proxy: Initial fetch status {initial_status} for {image_url}, Content-Type: {initial_content_type}")
            
            initial_response.raise_for_status() # Check initial response status

            if initial_content_type.startswith("image/"):
                logger.info(f"Proxy: URL {image_url} is a direct image. Streaming.")
                return StreamingResponse(io.BytesIO(initial_response.content), media_type=initial_content_type)
            
            elif initial_content_type.startswith("text/html"):
                logger.info(f"Proxy: URL {image_url} is HTML. Attempting to parse for image.")
                html_content = initial_response.text
                soup = BeautifulSoup(html_content, "lxml") # "lxml" is generally faster
                
                extracted_img_url = None
                meta_og_image = soup.find("meta", property="og:image")
                if meta_og_image and meta_og_image.get("content"):
                    extracted_img_url = meta_og_image["content"]
                    logger.info(f"Proxy: Found og:image URL: {extracted_img_url}")
                
                if not extracted_img_url:
                    meta_twitter_image = soup.find("meta", attrs={"name": "twitter:image"})
                    if meta_twitter_image and meta_twitter_image.get("content"):
                        extracted_img_url = meta_twitter_image["content"]
                        logger.info(f"Proxy: Found twitter:image URL: {extracted_img_url}")
                
                # Add more extraction strategies here if needed (e.g., JSON-LD, specific img tags)

                if extracted_img_url:
                    # Ensure the extracted URL is absolute
                    if not urlparse(extracted_img_url).scheme or not urlparse(extracted_img_url).netloc:
                        extracted_img_url = urljoin(image_url, extracted_img_url) # Handles relative paths correctly
                        logger.info(f"Proxy: Resolved relative extracted URL to: {extracted_img_url}")
                    
                    # Fetch and stream the image from the extracted URL
                    return await fetch_and_stream_image_content(extracted_img_url, client, image_url)
                else:
                    logger.error(f"Proxy: Could not extract direct image URL from HTML at {image_url}")
                    raise HTTPException(status_code=404, detail="No direct image link found on the page.")
            else:
                logger.error(f"Proxy: URL {image_url} has unhandled Content-Type: {initial_content_type}")
                raise HTTPException(status_code=415, detail=f"Unsupported content type from source: {initial_content_type}")

        except HTTPException:
            raise
        except httpx.HTTPStatusError as e:
            logger.error(f"Proxy (HTTPStatusError): {e.request.url} - Status {e.response.status_code} - Response: {e.response.text[:200]}")
            status_to_return = e.response.status_code if 400 <= e.response.status_code < 600 else 502
            raise HTTPException(status_code=status_to_return, detail=f"Upstream server error: {e.response.status_code}")
        except httpx.RequestError as e:
            logger.error(f"Proxy (RequestError): {e.request.url} - {str(e)}")
            raise HTTPException(status_code=502, detail=f"Network error while proxying: {str(e)}")
        except Exception as e:
            logger.exception(f"❌ Unexpected error in proxy_image for {image_url}")
            raise HTTPException(status_code=500, detail=f"Internal proxy error: {str(e)}")