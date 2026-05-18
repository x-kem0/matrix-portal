defmodule Formatter do
  defp p(lines) do
    joined = Enum.join(lines, "<br>")
    "<p>#{joined}</p>"
  end

  def fmt_bio(bio) do
    lines =
      bio
      |> String.trim()
      |> String.split("\n")

    has_paragraphs = Enum.find(lines, fn line -> line == "" end) != nil

    if has_paragraphs do
      {paragraphs, last_p_lines} =
        Enum.reduce(
          lines,
          {[], []},
          fn line, {p_acc, line_acc} ->
            if line == "" do
              {[p(line_acc |> Enum.reverse()) | p_acc], []}
            else
              {p_acc, [line | line_acc]}
            end
          end
        )

      [
        p(last_p_lines) | paragraphs
      ]
      |> Enum.reverse()
      |> Enum.join("\n")
    else
      Enum.join(lines, "<br>")
    end
  end
end
