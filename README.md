The Concentration style flip card game has been reorganized to support the MVVM (Model-View-ViewModel) architecture. 

**Model**

GameModel (Model) contains the game logic. It keeps track of which cards are turned up - whether cards have been matched, the running counter of how many flips and if all 12 pairs are matched (a win!). GameModel incorporates an array of Cards - each card contains the appropriate image and flip state (up or down).

**View**

ContentView (View) contains the presentation logic. It is responsible for displaying the 24 cards and solely responsible for organizing the grid into 4x6, 6x4 or 8x3 depending on optimal layout.

ContentView handles the animation for flipping cards, wiggling cards and showing confetti on a win.

**View Model**

GameViewModel operates as the intermediary between the Model and View. In this particular application, a view model is arguably overly complex but organizing in this manner is a good exercise to explore this architecture pattern.

Most of GameViewModel is straight pass through between the Model and View but there are a few mechanisms that seem to fit the View Model well. First are timers to control how long the cards wiggle when matched or the game is won. Second is a timer and logic  to control how long the cards stay face up after the second card is flipped and there is no match.

Further discussion about [Functionality](./Functionality.md).

Some details about the automated [Build pipeline](./Build.md).

https://github.com/user-attachments/assets/05bdcccc-7405-4504-9cb7-db8284ac102c

