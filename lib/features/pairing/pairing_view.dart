import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/jigu_controls.dart';
import '../../core/widgets/lily_bloom.dart';

class PairingView extends StatefulWidget {
  const PairingView({
    super.key,
    required this.code,
    required this.busy,
    required this.onJoin,
  });
  final String code;
  final bool busy;
  final ValueChanged<String> onJoin;
  @override
  State<PairingView> createState() => _PairingViewState();
}

class _PairingViewState extends State<PairingView> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
    children: [
      const PageHeading(
        title: 'Better together.',
        subtitle: 'One little code brings your worlds together.',
      ),
      GlassSurface(
        child: Column(
          children: [
            const LilyBloom(size: 64),
            const SizedBox(height: 18),
            Text(
              'An invitation for your person',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your secret code privately.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              label: 'Your secret code ${widget.code}',
              excludeSemantics: true,
              child: Row(
                children: List.generate(
                  6,
                  (i) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 5 ? 5 : 0),
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .64),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        i < widget.code.length ? widget.code[i] : '–',
                        style: const TextStyle(fontSize: 25, color: plum),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: widget.code.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: widget.code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Your code is copied.')),
                        );
                      }
                    },
              icon: const Icon(CupertinoIcons.doc_on_doc, size: 17),
              label: const Text('Copy invitation code'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      GlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Have their code?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            const Text('Enter the six digits they shared with you.'),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              enabled: !widget.busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                color: plum,
              ),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
                semanticCounterText: 'Six digit partner code',
              ),
              onSubmitted: (_) {
                if (!widget.busy && controller.text.length == 6) {
                  widget.onJoin(controller.text);
                }
              },
            ),
            const SizedBox(height: 18),
            JiguButton(
              label: 'Connect our space',
              icon: CupertinoIcons.heart,
              busy: widget.busy,
              onPressed: controller.text.length == 6
                  ? () => widget.onJoin(controller.text)
                  : null,
            ),
          ],
        ),
      ),
    ],
  );
}
