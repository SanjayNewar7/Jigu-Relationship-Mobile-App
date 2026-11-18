import 'package:flutter/material.dart';
import '../../../core/errors/app_error.dart';
import '../../../services/giphy_service.dart';

class GiphyPicker extends StatefulWidget {
  const GiphyPicker({super.key});
  @override
  State<GiphyPicker> createState() => _GiphyPickerState();
}

class _GiphyPickerState extends State<GiphyPicker> {
  final service = GiphyService(), query = TextEditingController();
  List<GiphyGif> results = [];
  bool busy = true, more = true;
  String? error;
  String searched = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> load({bool next = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    if (!next) {
      searched = query.text;
      results = [];
    }
    try {
      final gifs = await service.search(searched, offset: results.length);
      if (mounted) {
        setState(() {
          results.addAll(gifs);
          more = gifs.length == 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = AppError.message(
            e,
            fallback: 'GIF search is unavailable. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Text('Say it with a GIF', style: TextStyle(fontSize: 23)),
            const SizedBox(height: 12),
            TextField(
              controller: query,
              maxLength: 100,
              onSubmitted: busy ? null : (_) => load(),
              decoration: InputDecoration(
                hintText: 'Search GIPHY',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: busy ? null : () => load(),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (error != null)
              TextButton(
                onPressed: () => load(),
                child: Text('$error Tap to retry.'),
              ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final gif = results[i];
                  return InkWell(
                    onTap: () => Navigator.pop(context, gif),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        gif.url,
                        fit: BoxFit.cover,
                        semanticLabel: gif.title,
                        errorBuilder: (_, e, s) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (busy)
              const LinearProgressIndicator()
            else if (more && results.isNotEmpty)
              TextButton(
                onPressed: () => load(next: true),
                child: const Text('More GIFs'),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Image.asset(
                'assets/branding/powered_by_giphy.png',
                width: 160,
                semanticLabel: 'Powered By GIPHY',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
