Elixir [ExUnit Formatter](https://hexdocs.pm/ex_unit/1.12.3/ExUnit.Formatter.html) за оценяване на домашни.

За да работи този formatter за оценяване на домашни, то трябва да добавите `test_check_formatter.ex` файла в някои от директориите, които се компилират.

Използване:
```elixir
➜ mix test --formatter TestCheckFormatter
Compiling 1 file (.ex)

Failed tests:
1. test/hw2_test.exs:31 (task_id: sort)

Report:
  Max points for the current homework: 15
  Tasks: 14
  Tasks have at least one failed test: 1
  Tasks that don't have failing tests: 13
  Percent successful tests: 93.0%

  Points assigned: 13.95
```

Тест файлът трябва да има няколко тага:
- `@moduletag max_points: <number>` в началото на тест модула;
- `@tag task: <task>` над всеки тест. Няколко теста могат да имат
   едно име. Ако поне един от тези тестове "гръмне", то задачата
   <task> се счита за грешна.
