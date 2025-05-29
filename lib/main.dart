import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Colors.teal;

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData(brightness: Brightness.light).textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: seedColor[700],
        foregroundColor: Colors.white,
        elevation: 4.0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0), // Removed for broader compatibility in previous step
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle:
              GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: seedColor[50],
        selectedTileColor: seedColor[100],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey[850],
        contentTextStyle:
            GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        //margin: const EdgeInsets.fromLTRB(10,5,10,10), // Added margin for floating SnackBar
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: seedColor[600],
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: seedColor[800],
        foregroundColor: Colors.white,
        elevation: 4.0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0), // Removed for broader compatibility in previous step
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor[500],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle:
              GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: seedColor[800]?.withOpacity(0.4),
        selectedTileColor: seedColor[700],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey[700],
        contentTextStyle:
            GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        //margin: const EdgeInsets.fromLTRB(10,5,10,10), // Added margin for floating SnackBar
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: seedColor[400],
      ),
    );

    return MaterialApp(
      title: 'Menu Visualizer',
      theme: lightTheme,
      darkTheme: darkTheme, // You can switch between themes or use system theme
      home: const MenuAnalyzerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MenuAnalyzerPage extends StatefulWidget {
  const MenuAnalyzerPage({super.key});
  @override
  State<MenuAnalyzerPage> createState() => _MenuAnalyzerPageState();
}

class _MenuAnalyzerPageState extends State<MenuAnalyzerPage> {
  Uint8List? _imageBytes;
  bool _isAnalyzingMenu = false;
  bool _isFetchingDishImage = false;
  List<String> _menuItems = [];
  String? _selectedDish;
  String? _dishImageUrl; // This will now store the proxied URL

  final ImagePicker _picker = ImagePicker();
  // Ensure API_BASE_URL is set in your Flutter app's .env file
  // e.g., API_BASE_URL=http://10.0.2.2:8000 (for Android emulator)
  // or API_BASE_URL=http://localhost:8000 (for iOS simulator/web)
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000';


  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _isAnalyzingMenu = true;
        _menuItems = [];
        _selectedDish = null;
        _dishImageUrl = null;
      });
      await _analyzeMenu();
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
      if (mounted) {
        setState(() => _isAnalyzingMenu = false);
      }
    }
  }

  Future<void> _analyzeMenu() async {
    if (_imageBytes == null) {
      if (mounted) setState(() => _isAnalyzingMenu = false);
      return;
    }
    try {
      final uri = Uri.parse('$_baseUrl/upload_menu/');
      final req = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          _imageBytes!,
          filename: 'menu.jpg', // Filename is often useful for servers
        ));
      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (resp.statusCode != 200) {
        String errorDetail = "Unknown server error";
        try {
          final errorJson = jsonDecode(resp.body) as Map<String, dynamic>;
          errorDetail = errorJson['detail'] ?? resp.body;
        } catch (_) {
          errorDetail = resp.body;
        }
        throw Exception('Server error ${resp.statusCode}: $errorDetail');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['status'] == 'error' || data['status'] == 'success_ocr_only') {
         // Handle cases where LLM filtering might have failed or was skipped
         final message = data['message'] as String? ?? 'Could not fully process menu items.';
         _showErrorSnackBar(message);
         // Still try to display whatever items were returned
      }

      final items = (data['items'] as List?)?.cast<String>() ?? [];
      setState(() => _menuItems = items);

      if (items.isEmpty && data['status'] != 'error' ) { // Avoid double snackbar if already shown
        _showErrorSnackBar('No menu items were detected by the server.');
      }
    } catch (e) {
      _showErrorSnackBar('Error analyzing menu: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingMenu = false);
    }
  }

  Future<void> _onDishTap(String dish) async {
    setState(() {
      _isFetchingDishImage = true;
      _selectedDish = dish;
      _dishImageUrl = null; // Clear previous image
    });

    try {
      final uri = Uri.parse('$_baseUrl/get_dish_image/');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'dish': dish}),
      );

      if (!mounted) return;

      if (resp.statusCode != 200) {
        String errorDetail = "Unknown server error";
        try {
          final errorJson = jsonDecode(resp.body) as Map<String, dynamic>;
          errorDetail = errorJson['detail'] ?? resp.body;
        } catch (_) {
          errorDetail = resp.body;
        }
        throw Exception('Server error ${resp.statusCode}: $errorDetail');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final originalImageUrl = data['url'] as String?;

      if (originalImageUrl != null && originalImageUrl.isNotEmpty) {
        // *** MODIFICATION: Construct proxied URL ***
        String encodedOriginalUrl = Uri.encodeComponent(originalImageUrl);
        setState(() {
          _dishImageUrl = '$_baseUrl/proxy_image/?image_url=$encodedOriginalUrl';
        });
      } else {
        setState(() {
          _dishImageUrl = null; // Ensure it's null if no URL from backend
        });
        _showErrorSnackBar('No image found for "$dish" from server.');
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching dish image: $e');
      setState(() {
         _dishImageUrl = null; // Clear URL on error
      });
    } finally {
      if (mounted) setState(() => _isFetchingDishImage = false);
    }
  }

  void _clearImage() => setState(() {
        _imageBytes = null;
        _menuItems = [];
        _selectedDish = null;
        _dishImageUrl = null;
        _isAnalyzingMenu = false;
        _isFetchingDishImage = false;
      });

  void _clearSelectedDish() => setState(() {
        _selectedDish = null;
        _dishImageUrl = null; // Keep this null, _onDishTap will repopulate if needed
        _isFetchingDishImage = false;
      });

  Widget _buildImagePickerButtons() => Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Take Photo'),
              onPressed:
                  _isAnalyzingMenu ? null : () => _pickImage(ImageSource.camera),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
              onPressed: _isAnalyzingMenu
                  ? null
                  : () => _pickImage(ImageSource.gallery),
            ),
          ),
        ],
      );

  Widget _buildMenuPreview() {
    if (_imageBytes == null) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.memory(
                  _imageBytes!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
              Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white, size: 20),
                  onPressed: _clearImage,
                  tooltip: 'Clear Image',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemsList() {
    if (_menuItems.isEmpty ||
        _imageBytes == null ||
        _isAnalyzingMenu) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Select a dish to see an image:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _menuItems.length,
          itemBuilder: (context, index) {
            final item = _menuItems[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                title: Text(item,
                    style: Theme.of(context).textTheme.bodyLarge),
                trailing: Icon(Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary),
                onTap: () => _onDishTap(item),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDishResult() {
    if (_isFetchingDishImage) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // If _dishImageUrl is null (either no image found, or error occurred, or not yet fetched for selected dish)
    if (_dishImageUrl == null) {
      if (_selectedDish != null && !_isFetchingDishImage) { // Only show "could not load" if a dish was selected and we are done trying
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Center(
            child: Text(
              'Image for "${_selectedDish!}" is currently unavailable.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        );
      }
      return const SizedBox.shrink(); // Otherwise, nothing to show (e.g. before any selection)
    }

    // If _dishImageUrl is not null, attempt to display it
    return Column(
      children: [
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
          child: Card(
            key: ValueKey(_dishImageUrl), // Use the URL itself as the key for AnimatedSwitcher
            elevation: 5,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: _dishImageUrl!, // This is now the proxied URL
              fit: BoxFit.contain,
              height: 300,
              width: double.infinity,
              placeholder: (c, u) => Shimmer.fromColors(
                baseColor:
                    Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                highlightColor:
                    Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.05),
                child: Container(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    height: 300,
                    width: double.infinity),
              ),
              errorWidget: (c, u, e) {
                // This error is for CachedNetworkImage failing to load the proxied URL.
                // It could mean the proxy endpoint itself failed, or the original image was truly inaccessible by the proxy.
                print("CachedNetworkImage Error for URL: $u, Error: $e"); // Log for debugging
                return Container(
                  height: 300,
                  width: double.infinity,
                  color:
                      Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 70,
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer
                              .withOpacity(0.7)),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Preview not available',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer
                                  .withOpacity(0.9)),
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialPrompt() {
    if (_imageBytes != null || _isAnalyzingMenu) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner_outlined,
                size: 80,
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withOpacity(0.8)),
            const SizedBox(height: 24),
            Text(
              '📸 Scan a menu to see the magic!',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Use the buttons above to take a photo of a menu or select one from your gallery.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuListContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImagePickerButtons(),
          _buildInitialPrompt(),
          _buildMenuPreview(),
          if (_isAnalyzingMenu && _imageBytes != null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          _buildMenuItemsList(),
          if (!_isAnalyzingMenu &&
              _imageBytes != null &&
              _menuItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text(
                  'No menu items were detected.\nPlease try a clearer photo or a different section of the menu.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );

  Widget _buildDishDetailContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              label: const Text('Back to Menu'),
              onPressed: _clearSelectedDish,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_selectedDish != null) // Show dish name only if a dish is selected
            Padding( // Added Padding for spacing
              padding: const EdgeInsets.only(bottom: 8.0), // Space between name and image
              child: Text(
                _selectedDish!,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary),
                textAlign: TextAlign.center,
              ),
            ),
          _buildDishResult(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _selectedDish == null ? 'Menu Visualizer 🍲' : 'Dish Preview'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: _selectedDish == null
              ? _buildMenuListContent()
              : _buildDishDetailContent(),
        ),
      ),
    );
  }
}