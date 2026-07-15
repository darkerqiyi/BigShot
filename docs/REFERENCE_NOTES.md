# Reference Research Notes and Originality Boundary

Research date: 2026-07-13. These notes identify high-level design patterns only; they are not a specification to reproduce any reference title.

## Observed patterns

- SNK describes Metal Slug as a classic 2D run-and-gun/action shooting series and emphasizes simple, intuitive controls with fast-paced play. Useful abstraction: low input complexity, quick action comprehension, and sustained forward pressure.
- Official series history shows weapons and stage gimmicks being used to create different combat behavior. Useful abstraction: weapons should change spacing and risk, not merely damage numbers.
- Contemporary descriptions of `炮炮火枪手` characterize it as a cartoon competitive shooter using mouse aiming in a side-view format, with terrain mechanisms and weapon traits affecting combat. Useful abstraction: allow precise pointing-device aim later while keeping targets and hazards readable.
- Available descriptions identify `弹头奇兵` as a planar side-scrolling online shooter and emphasize shooting feel and fair competition in later adaptations. Useful abstraction: responsive control and clearly attributable hits matter more than progression complexity.

## What this project will not copy

- No reference title's code, decompiled behavior constants, assets, animation frames, silhouettes, names, story, dialogue, UI, level layouts, enemy or boss designs, sound effects, music, or marketing language.
- No attempt to recreate a particular stage, character, weapon skin, vehicle, or exact control quirk.
- Placeholder shapes and original neutral terminology will be used until an original visual direction is approved.

## Sources

- SNK, Metal Slug 30th Anniversary: https://www.snk-corp.co.jp/us/anniversary/metalslug30th/
- SNK, Metal Slug series history: https://www.snk-corp.co.jp/us/anniversary/metalslug30th/history/
- SNK, Metal Slug XX: https://www.snk-corp.co.jp/us/games/metalslugxx/
- ZOL overview of 炮炮火枪手: https://youxi.zol.com.cn/ol/index5079.html
- ZOL article describing its mouse-aiming model: https://game.zol.com.cn/65/656652.html
- Wikipedia overview of 弹头奇兵 (used only for basic classification): https://zh.wikipedia.org/wiki/%E5%BC%B9%E5%A4%B4%E5%A5%87%E5%85%B5
- Godot stable command-line documentation: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html

