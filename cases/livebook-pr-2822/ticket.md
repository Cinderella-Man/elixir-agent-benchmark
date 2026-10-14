# Failed evaluation erases earlier imports and process dictionary

After a cell raises, later cells can lose imports and process dictionary values established by earlier successful cells. For example, import ExUnit.Assertions, then evaluate a failing assertion: another assertion should remain available afterward.

A failed evaluation must preserve earlier imported functions and macros and earlier process dictionary values. Changes attempted by the failed cell must not replace those values or leak its new bindings, aliases, requires or modules into later evaluation. Combining prior successful contexts with the errored evaluation should retain the same guarantees.

Repair evaluation state handling and add regression coverage through evaluator requests.

Preserve the exact previously imported function and macro selections, including selective imports, rather than broadening them after a failure. Values written to the process dictionary by a failed cell must be rolled back to the earlier successful state.
