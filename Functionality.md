**Layout**

A fair amount of effort went into optimizing the tile grid. The app was designed to work on iphone and ipad in both landscape and portrait mode. It was decided to ensure the 24 tiles would fit on the screen without scrolling.

To accomplish this the geometry calculations take into account the device, orientation and available UI space. A 4x6 grid is used in portrait mode, a 6x4 grid in ipad landscape and 8x3 in iphone landscape.

**Game Center Integration**

The application is integrated to Apple Game Center to track the players’ personal best and show the global leaderboard.

Apple provides APIs to write scores to the leaderboard and solicit the players’ personal best. There is also an API to render the leaderboard as an overlay linked to a button/icon on the top of the game.

**Progress Bar**

Earlier exercises introduced the progress bar; this application adds a progress bar to the bottom of the screen to demonstrate same.
