# SnapMenu 📸🍲

SnapMenu allows you to snap a photo of a restaurant menu, intelligently extract the dish names, and then see what those dishes look like! It uses a Flutter frontend and a Python FastAPI backend powered by Google Cloud Vision API, Google Custom Search, and Gemini for an enhanced user experience.

## ✨ Features

* **Menu OCR**: Upload a menu image to extract all visible text.
* **AI-Powered Dish Identification**: Leverages a Gemini model to intelligently filter OCR'd text and identify actual dish names, excluding headers, descriptions, and other non-dish text.
* **Smarter Dish Image Search**: Uses Gemini to generate optimized search queries for Google Custom Search to find more relevant images of prepared dishes.
* **CORS-Friendly Image Proxy**: Backend includes an image proxy to securely fetch and display images from various external sources in the Flutter web app, avoiding common CORS issues.
* **Interactive Flutter UI**: A user-friendly interface built with Flutter for seamless menu uploads and dish image Browse.

---
## 🛠️ Tech Stack

* **Frontend**: Flutter
* **Backend**: Python, FastAPI
* **AI/ML Services**:
    * Google Cloud Vision API (for OCR)
    * Google Custom Search Engine API (for image lookups)
    * Google Gemini (via `google-generativeai` SDK for text processing and query enhancement)
* **Backend Development Tools**: `python-dotenv`, `requests`, `httpx`, `uvicorn`

---
## 🚀 Getting Started

### 1. Backend Setup (`adk_backend` folder)

The backend handles image processing, OCR, AI-based text filtering, and image searching.

1.  **Navigate to the backend directory:**
    ```bash
    cd path/to/your/project/adk_backend
    ```
2.  **Create and activate a Python virtual environment:**
    ```bash
    python -m venv .venv
    # Windows
    .\.venv\Scripts\activate
    # macOS/Linux
    source .venv/bin/activate
    ```
3.  **Install Dependencies:**
    Make sure you have a `requirements.txt` file in your `adk_backend` directory. It should include:
    ```txt
    fastapi
    uvicorn[standard]
    python-dotenv
    requests
    google-generativeai
    # google-cloud-aiplatform (if needed by your ADK version, otherwise google-generativeai is primary for direct Gemini calls)
    httpx
    # any other specific google.adk.agents dependencies
    ```
    Then install:
    ```bash
    pip install -r requirements.txt
    ```
4.  **Environment Variables (`.env` file) 🔑:**
    This project requires API keys for Google Cloud services. A `.env` file is included in the `adk_backend` directory with placeholder values. **You MUST replace these placeholders with your actual API keys.**

    Create or ensure your `.env` file in the `adk_backend` directory looks like this:
    ```env
    VISION_API_KEY=YOUR_GOOGLE_VISION_API_KEY_HERE
    CSE_API_KEY=YOUR_GOOGLE_CUSTOM_SEARCH_API_KEY_HERE
    CSE_CX=YOUR_CUSTOM_SEARCH_ENGINE_ID_HERE
    GEMINI_API_KEY=YOUR_GOOGLE_GEMINI_API_KEY_HERE
    ```
    * `VISION_API_KEY`: For Google Cloud Vision API (OCR).
    * `CSE_API_KEY`: For Google Custom Search Engine API.
    * `CSE_CX`: Your Custom Search Engine ID (configure this in the Google CSE control panel to search images).
    * `GEMINI_API_KEY`: For the Gemini API (used for intelligent filtering and query generation). Ensure this key has the "Generative Language API" or "Vertex AI API" enabled as appropriate for the SDK usage.

5.  **Run the FastAPI Server:**
    ```bash
    uvicorn agent:app --reload --host 0.0.0.0 --port 8000
    ```
    The backend should now be running, typically accessible at `http://127.0.0.1:8000` from the host machine.

---
### 2. Flutter Application Setup (Frontend)

The Flutter app provides the user interface.

1.  **Navigate to your Flutter project directory.**
2.  **Environment Variables (`.env` file for Flutter):**
    The Flutter app needs to know the backend's base URL. Create a `.env` file in the root of your Flutter project with the following (adjust the URL as needed):
    ```env
    API_BASE_URL=[http://127.0.0.1:8000](http://127.0.0.1:8000)
    ```
    * **For Android Emulator (if backend is on host localhost):** Use `API_BASE_URL=http://10.0.2.2:8000`
    * **For iOS Simulator (if backend is on host localhost):** `API_BASE_URL=http://localhost:8000` works.
    * **For physical device testing:** Use your computer's LAN IP address (e.g., `http://192.168.1.X:8000`) and ensure your backend Uvicorn server is running on `0.0.0.0`.

3.  **Get Flutter Packages:**
    ```bash
    flutter pub get
    ```
4.  **Run the App:**
    ```bash
    flutter run
    ```
    Select your desired device (mobile emulator/simulator, physical device, or web browser).

---
## 📌 Important Notes

* **API Keys**: The application **will not work** without valid API keys for Google Cloud services correctly set in the backend's `.env` file.
* **CORS Configuration**: The backend (`agent.py`) currently uses `allow_origins=["*"]` for CORS. This is permissive and suitable for development. **For a production environment, you MUST restrict `allow_origins` to the specific domain(s) of your deployed Flutter application** to enhance security.
* **Custom Search Engine (CSE)**: Ensure your Google Custom Search Engine (identified by `CSE_CX`) is configured to search the entire web for images or specific sites that are good sources for dish photos.

---
---
## 🎮 How to Use SnapMenu

1.  **Launch the Flutter Application**: Ensure your backend server is running, then start the Flutter app on your chosen device/emulator or web browser.
2.  **Upload a Menu**:
    * On the main screen, you'll find options to "Take Photo" of a menu or select an image from your "Gallery".
    * After selecting an image, it will be uploaded to the backend for processing.
3.  **View Extracted Dishes**:
    * The backend will perform OCR and then use Gemini to intelligently filter and identify dish names from the menu.
    * The list of identified dish names will be displayed in the app.
4.  **See Dish Images**:
    * Tap on any dish name from the list.
    * The app will request an image for that dish from the backend. The backend uses an LLM-enhanced Google Custom Search query to find a relevant photo.
    * The image (or a "preview not available" message if an image can't be found/loaded) will be displayed.
5.  **Navigate**: Use the "Back to Menu" button to return from the dish image view to the list of extracted dishes. You can clear the current menu image to upload a new one.

---
## ⚙️ Backend API Endpoints (`adk_backend`)

The FastAPI backend exposes the following main endpoints (running on `http://127.0.0.1:8000` by default):

* **`POST /upload_menu/`**:
    * **Request**: `multipart/form-data` with a `file` field containing the menu image.
    * **Response**: JSON object with `status` and `items` (a list of identified dish names) or an error message.
        ```json
        {
          "status": "success", // or "success_ocr_only" or "error"
          "items": ["Spaghetti Carbonara", "Caesar Salad", ...],
          "message": "Optional message" // e.g., if LLM filtering was skipped
        }
        ```

* **`POST /get_dish_image/`**:
    * **Request**: JSON body with the dish name.
        ```json
        {
          "dish": "Spaghetti Carbonara"
        }
        ```
    * **Response**: JSON object with `status` and `url` (the URL of the dish image found by Google Custom Search) or an error message.
        ```json
        {
          "status": "success", // or "error"
          "url": "[http://example.com/path/to/image.jpg](http://example.com/path/to/image.jpg)"
        }
        ```

* **`GET /proxy_image/`**:
    * **Request**: Query parameter `image_url` containing the URL-encoded original image URL.
        Example: `/proxy_image/?image_url=https%3A%2F%2Fexternal.com%2Fimage.jpg`
    * **Response**: Streams the image content directly with the appropriate `Content-Type`, or an HTTP error if the image cannot be fetched or is not a valid image type.

---
## 🤔 Troubleshooting

* **`RuntimeError: ... API_KEY not set in environment`**:
    * Ensure the respective API key (`VISION_API_KEY`, `CSE_API_KEY`, `CSE_CX`, `GEMINI_API_KEY`) is correctly set in the `.env` file within your `adk_backend` directory.
    * Make sure `load_dotenv()` is called at the very beginning of your `agent.py`.
    * Restart your Uvicorn server after modifying the `.env` file.

* **Flutter app can't connect to the backend / `API_BASE_URL` issues**:
    * If using an Android Emulator, ensure `API_BASE_URL` in the Flutter app's `.env` file is set to `http://10.0.2.2:8000` (if your backend is on `localhost:8000`).
    * If using a physical device, ensure your backend Uvicorn server is running on `0.0.0.0` (e.g., `uvicorn agent:app --host 0.0.0.0 --port 8000`) and your Flutter app uses your computer's LAN IP address for `API_BASE_URL`.
    * Check for firewall issues that might be blocking connections.

* **CORS errors in Flutter Web**:
    * Ensure `CORSMiddleware` is correctly configured in `agent.py` in your FastAPI backend. For development, `allow_origins=["*"]` is common, but for production, specify your Flutter web app's actual domain(s).
    * The image proxy (`/proxy_image/`) is designed to solve CORS for images from *external* sites. If you get CORS errors for your *own backend endpoints*, it's the `CORSMiddleware` on your FastAPI app that needs checking.

* **Irrelevant dish images / No image found**:
    * The quality of image search depends on the Google Custom Search Engine and the queries generated by Gemini.
    * You can experiment with the `query_generation_prompt` within the `search_image` function in `agent.py` to try and improve query effectiveness.
    * Ensure your `CSE_CX` (Custom Search Engine ID) is configured correctly and is set to search the web for images.
    * Some dishes may genuinely have few good, publicly available images.

* **`415 Unsupported Media Type` for some images (from `/proxy_image/`)**:
    * This is expected behavior if the URL returned by Google Custom Search points to an HTML page (like some Instagram links) instead of a direct image file. The proxy correctly identifies this and stops, preventing an error in your Flutter app. The Flutter app's `errorWidget` for `CachedNetworkImage` should handle this gracefully.

---
## 💡 Future Enhancements

* **Improved Dish Image Selection**: Fetch multiple image results from CSE and use image analysis or a multimodal LLM to select the best, most representative "prepared dish" photo.
* **User Feedback for Images**: Allow users to report if an image is incorrect.
* **Caching**: Implement caching for OCR results or image search results in the backend to reduce API calls and latency for frequently accessed menus/dishes.
* **More Detailed Dish Information**: Extend to fetch dish descriptions, ingredients, or even nutritional information.
* **UI/UX Polish**: Add animations, improved loading states, and more refined UI elements in the Flutter app.
* **Localization/Multiple Languages**: Support for menus in different languages.
* **Price Extraction**: Attempt to extract and display prices alongside dish names.
* **User Accounts & Saved Menus**: Allow users to save processed menus.

---

## Questions?

* **Email**: You can reach me at `[me@desouki.com]`.
* **GitHub Profile**: [Desouki27](https://github.com/Desouki27) (You can also contact me via my GitHub profile).
* **LinkedIn**: [Mohamed Desouki](https://www.linkedin.com/in/mohdesouki)

---
