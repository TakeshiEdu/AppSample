import 'package:flutter/material.dart';

class TaskInput extends StatefulWidget {
  const TaskInput({super.key, required this.onAdd});

  final Future<bool> Function(String title) onAdd;

  @override
  State<TaskInput> createState() => _TaskInputState();
}

class _TaskInputState extends State<TaskInput> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || title.length > 80) {
      setState(() {
        _errorText = title.isEmpty ? 'タスク名を入力してください' : '80文字以内で入力してください';
      });
      return;
    }
    if (await widget.onAdd(title) && mounted) {
      _controller.clear();
      setState(() => _errorText = null);
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: '新しいタスク',
              hintText: 'やることを入力',
              errorText: _errorText,
              prefixIcon: const Icon(Icons.add_task),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
        ),
      ],
    );
  }
}
