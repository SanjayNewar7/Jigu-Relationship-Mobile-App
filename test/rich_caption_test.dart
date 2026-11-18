import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/moment_editor/controllers/rich_caption_controller.dart';
import 'package:jigulove/features/moment_editor/models/rich_caption.dart';

void main() {
 test('selected words retain formatting through insertion and deletion', () {
  final c=RichCaptionController();addTearDown(c.dispose);
  c.text='love you';
  c.selection=const TextSelection(baseOffset:5,extentOffset:8);
  c.format((m)=>m.copy(bold:true));
  expect(c.marks.take(5).every((m)=>!m.bold),isTrue);
  expect(c.marks.skip(5).every((m)=>m.bold),isTrue);
  c.value=const TextEditingValue(text:'love you!',selection:TextSelection.collapsed(offset:9));
  expect(c.marks.last.bold,isTrue);
  c.value=const TextEditingValue(text:'you!',selection:TextSelection.collapsed(offset:4));
  expect(c.marks.length,4);expect(c.marks.every((m)=>m.bold),isTrue);
 });
 test('rich caption serialization preserves selected color and emoji', () {
  final c=RichCaptionController();addTearDown(c.dispose);
  c.text='Us \u{1f495}';
  c.selection=const TextSelection(baseOffset:0,extentOffset:2);
  c.format((m)=>m.copy(color:0xffd86b93,italic:true,underline:true));
  final restored=RichCaption.fromMap(RichCaption(text:c.text,marks:List.of(c.marks)).toMap());
  expect(restored.text,c.text);expect(restored.marks.first.color,0xffd86b93);
  expect(restored.marks.last.color,0xffffffff);
  expect(restored.span.toPlainText(),c.text);
 });
}
