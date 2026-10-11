# Long numbered lists lose nested content when formatted

Opening and saving a notebook can change the nesting of a long numbered list. Nested bullets under item 10 become siblings, and fenced code under item 11 can lose its parent association.

Markdown formatting must preserve the structure of numbered lists as their item numbers grow, including nested bullet lists and fenced code blocks. This should also work with three-digit item numbers. Existing single-digit and unordered list formatting must remain correct, and repeating a formatting round trip should be stable.

Repair the formatting behavior and add regression coverage.
