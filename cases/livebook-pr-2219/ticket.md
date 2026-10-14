# Inputs introduced by frame updates render blank

In a notebook session, update a rendered frame to contain a text input with a label and a default value. The input can appear blank until an unrelated interaction causes the page to rerender.

For example, render a frame, then replace its contents with an input labeled "Name" whose default value is "Jane". Immediately after the update, the notebook must show both the label and the default value. Frame updates should preserve the ordinary behavior of existing outputs and inputs.

Repair this behavior and add a regression test through the notebook session's rendered output path.

The same guarantee applies to text and numeric inputs, nested output frames, and both replacement and appended frame contents.
