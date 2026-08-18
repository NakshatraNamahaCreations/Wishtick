import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// One block of a long-form document.
sealed class DocBlock {
  const DocBlock();
}

/// A bold section heading.
class DocHeading extends DocBlock {
  const DocHeading(this.text);

  final String text;
}

/// A paragraph. Blank-line separation is the caller's job — one block, one
/// paragraph.
class DocText extends DocBlock {
  const DocText(this.text, {this.bold = false});

  final String text;
  final bool bold;
}

/// A bulleted list.
class DocBullets extends DocBlock {
  const DocBullets(this.items);

  final List<String> items;
}

/// Renders a legal or informational document (`2262:1019`).
///
/// A block list rather than raw Markdown: the app has no Markdown renderer,
/// and these documents use exactly three shapes. Adding a dependency to render
/// three shapes would be the larger change.
class DocumentBody extends StatelessWidget {
  const DocumentBody({required this.blocks, super.key});

  final List<DocBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      itemCount: blocks.length,
      separatorBuilder: (context, index) => SizedBox(
        // A heading gets more air above it than a paragraph does.
        height: index + 1 < blocks.length && blocks[index + 1] is DocHeading
            ? AppSpacing.xxxl
            : AppSpacing.lg,
      ),
      itemBuilder: (context, index) => switch (blocks[index]) {
        DocHeading(:final text) => Text(
          text,
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        DocText(:final text, :final bold) => Text(
          text,
          style: context.text.bodyMedium?.copyWith(
            color: bold ? colors.textPrimary : colors.textSecondary,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            height: 1.6,
          ),
        ),
        DocBullets(:final items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      },
    );
  }
}
