## Animation

There are several animations in this application. 

First is an animation when flipping the card. Some effort went into ensuring the animation was smooth and ensuring the back of the card transitioned to the front of the card at the right time. It also was designed so the flip “reverses” when a card goes back to face down.

Second is an animation to wiggle the two cards that were immediately matched for a small time. The same animation logic is used to wiggle all the cards when the player solves the puzzle.

Third, at the beginning of the game, there is an animation to "[deal](lab3/blob/e90abffa019419988c89aea64f039f4d16dd9f14/lab3/ContentView.swift#L238)" the cards into the grid.

Lastly, there's an animation when the player wins - one of either [fireworks](./lab3/FireworksView.swift), [confetti](./lab3/ConfettiView.swift) or [balloons](./lab3/BalloonAscentView.swift).

For the card flip and the dealing we've used some short sound bite wav files from the asset catalog.

https://github.com/user-attachments/assets/598f2287-2418-491d-8bdd-7d27ed1800a0

