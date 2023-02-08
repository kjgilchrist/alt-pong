/*
  Anti-Pong Bullet Hell
 Mouse Wheel or L- and R-Arrow
 */

/* GLOBALS */
final int PAD_THICK = 12;
final int BALL_RADIUS = 7;
final int DIST_EDGE = 100;
final int MAX_VEL = 3;

String gameState;
int frames, timer, multi, score, highscore, overPause;
// Game over screen and high score?

// Currently not conventional naming for non-constants.
int PAD_SIZE;
int PAD_CHANGE;
int TRACK_RADIUS;
int BAR_RADIUS;

PVector center;
ArrayList<Paddle> paddles = new ArrayList<Paddle>();
ArrayList<Ball> balls = new ArrayList<Ball>();
ArrayList<Ball> deadBall = new ArrayList<Ball>();
int LIFES;
int BOMBS;

WriteText SCORE, TIMER, MULTIPLIER;

/* SETUP */
void setup() {
  frameRate(60);

  // Scaling to screen.
  fullScreen();

  // Initialize variables.
  TRACK_RADIUS = (displayHeight/2) - DIST_EDGE;
  BAR_RADIUS = TRACK_RADIUS + DIST_EDGE; // lol
  PAD_SIZE = 15;
  PAD_CHANGE = (int) PAD_SIZE / 5;
  frames = 0;
  timer = 0;
  gameState = "START";
  multi = 1;
  score = 0;
  highscore = 0;
  overPause = 0;

  // Write objects
  MULTIPLIER = new WriteText("x" + multi, -50, (-displayHeight/2 + 30), 4, 20, color(255));
  TIMER = new WriteText("" + timer, 0, (-displayHeight/2 + 30), 4, 20, color(255));
  SCORE = new WriteText("" + score, 50, (-displayHeight/2 + 30), 4, 20, color(255));

  // Define center vector for vector maths.
  center = new PVector(0, 0);
  // Add initial paddle and ball.
  paddles.add(new Paddle());
  balls.add(new Ball());
}

/* DRAW */
void draw() {
  // Things that are not related to Game State.
  // Screen settings. Translate origin to center.
  // Draw ellipse based on radius not diameter.
  background(0);
  translate(displayWidth/2, displayHeight/2);
  strokeCap(PROJECT);
  ellipseMode(RADIUS);
  textAlign(CENTER, CENTER);

  // GameState switch.
  switch (gameState) {
    // Main Menu.
  case "START":
    startGame();
    break;
    // Game is being actively played.
  case "PLAY":
    playGame();
    break;
    // Game has ended. Will be sent to Main Menu somehow.
  case "OVER":
    gameOver();
    break;
    // For non-matching switch parameter.
  default:
    gameFail();
    break;
  }
}

/* GameState Functions */
void startGame() {
  fill(255);
  textSize(40);
  if (highscore > 0) {
    text("SPIN TO START", 0, 0);
    textSize(20);
    text("HIGHSCORE: " + highscore, 0, 40);
  } else {
    text("SPIN TO START", 0, 0);
  }
}

void playGame() {
  // Draw circular "track". Draw vertical barriers.
  noFill();
  strokeWeight(2);
  stroke(15);
  circle(0, 0, TRACK_RADIUS);
  strokeWeight(4);
  stroke(255);
  line(-BAR_RADIUS, -displayHeight/2, -BAR_RADIUS, displayHeight/2);
  line(BAR_RADIUS, -displayHeight/2, BAR_RADIUS, displayHeight/2);

  // Check if ball is dead, remove. Then add more.
  balls.removeAll(deadBall);
  if (balls.size() <= 0) {
    balls.add(new Ball());
  }

  // Calculate multiplier and current score.
  multi = speedMult();

  // Add new balls.
  if ((frames % 60) == 0) {
    if (balls.size() > 20 && BOMBS == 0) {
      balls.add(new BallBomb());
    } else if (LIFES < 2) {
      balls.add(new BallLife());
    } else {
      balls.add(new Ball());
    }
    score = score + calcScore(multi, balls.size());
  }
  if ((frames % 120) == 0) {
    // Nothing atm
  }

  // Do the things with the things.
  for (Paddle paddle : paddles) {
    paddle.update();
    for (Ball ball : balls) {
      ball.collide(paddle);
      ball.update();
      ball.animate();
    }
  }
  frames++;
  timer = frames/60;

  // Show current game state.
  writeText();
}

void gameOver() {
  fill(255);
  textSize(40);
  text("GAME OVER", 0, 0);
  textSize(20);
  text("SCORE: " + score, 0, 40);
  if (overPause < 300) {
    overPause++;
  } else {
    overPause = 0;
    gameState = "START";
  }
}

void gameFail() {
  fill(255, 0, 0);
  textSize(20);
  text("FAILED TO LOAD", 0, 0);
  text("Please Restart", 0, 20);
}

/* PADDLE CLASS */
class Paddle {
  PVector polar; // r, theta
  String type = "Paddle";

  Paddle() {
    polar = new PVector();
    this.polar.x = TRACK_RADIUS;
    if (!paddles.isEmpty()) {
      this.polar.y = paddles.get(0).polar.y + ((360 / (paddles.size() + 1)) * paddles.indexOf(this));
    } else {
      this.polar.y = 0;
    }
  }

  void update() {
    // Update the amount of movement and check if GameOver.
    if (PAD_SIZE < 5) {
      PAD_CHANGE = 1;
    } else {
      PAD_CHANGE = (int) PAD_SIZE / 5;
    }
    if (PAD_SIZE <= 0) {
      // Check for new highscore.
      if (score > highscore) {
        highscore = score;
      }
      gameState = "OVER";
    }

    // Update the angle from a key press - outside of class.
    // Update angle based on Master Paddle.
    this.polar.y = (paddles.get(0).polar.y + ((360 / (paddles.size())) * paddles.indexOf(this))) % 360;
    // If angle is negative, add 360.
    if (this.polar.y < 0) {
      this.polar.y += 360;
    }

    // Variant paddles based on g = z. Subclasses?

    // Draw it.
    noFill();
    strokeWeight(PAD_THICK);
    stroke(255, 0, 0);
    arc(0, 0, this.polar.x, this.polar.x, (this.polar.y*(PI/180)), ((this.polar.y+PAD_SIZE)*(PI/180)));
  }
}

/* BALL SUPERCLASS / GENERIC */
class Ball {
  // Should I try in all polar? Let us pray.
  PVector position, velocity, acceleration, polar;
  color bColor;
  int radius, count, flag, collChange, frame;
  float wave;

  Ball() {
    position = new PVector(0, 0); // x, y
    velocity = PVector.random2D().mult(random(1, MAX_VEL)); // random unit vector
    polar = new PVector(0, 0); // distance from center, rotation around center
    radius = BALL_RADIUS;
    count = 0;
    flag = 0;
    bColor = color(255);
    collChange = -1;
    frame = 0;
  }

  void update() {
    //// Update wave from frames.
    //this.wave = sin(frames);
    //// Update velocity from wave.
    //this.velocity.rotate(wave);
    // Update position.
    this.position.add(this.velocity);
    // Calculate new polar based on new position.
    this.polar = getPolar(this.position);
    // Draw the ball at new position.
    fill(this.bColor);
    noStroke();
    circle(this.position.x, this.position.y, this.radius);
  }

  void collide(Paddle paddle) {
    // Use polar.
    // Check if the distance from future center and theta are within the paddle space.
    // When dealing with vectors, if you only want the VALUE, you must use .copy()
    // Otherwise you edit the original vector, as well.
    PVector fPosition = this.position.copy();
    fPosition.add(this.velocity);
    PVector fPolar = getPolar(fPosition);

    // Check for collision with edges of screen and barricades.
    if ((fPosition.x + this.radius) > (BAR_RADIUS)
      || (fPosition.x - this.radius) < (-BAR_RADIUS)) {
      this.velocity.x *= -1;
    }
    if ((fPosition.y + this.radius) > (displayHeight/2)
      || (fPosition.y - this.radius) < (-displayHeight/2)) {
      this.velocity.y *= -1;
    }

    // Collision Detection with Paddle
    if ((fPolar.x + this.radius) > (paddle.polar.x - PAD_THICK/2)
      && (fPolar.x - this.radius) < (paddle.polar.x + PAD_THICK/2)
      && (fPolar.y + 1) >= (paddle.polar.y)
      && (fPolar.y + 1) <= (paddle.polar.y + PAD_SIZE)) {
      // Check if Energized paddle.
      if (paddle.type == "Energy") {
        deadBall.add(this);
      }
      if (flag > 1) {
        // If the ball has collided more than once in a row (is stuck).
        // Will push in positive direction.
        this.position.x += (PAD_THICK/2 + 1);
        this.position.y += (PAD_THICK/2 + 1);
        this.velocity.rotate(PI);
        this.flag = 0;
      } else {
        // Calculate the reflected vector based on current direction.
        PVector normal = fPosition.normalize();
        float dot = 2 * this.velocity.dot(normal);
        PVector fVelocity = this.velocity.sub(normal.mult(dot));
        this.velocity = fVelocity.copy();
        this.count = 1;
        this.flag++;
        this.bColor = color(0, 0, 255);
        PAD_SIZE += collChange;
      }
      //PAD_SIZE += collChange;
    } else {
      this.flag = 0;
      if (this.count > 0 && this.count < 10) {
        this.count++;
      } else if (this.count == 10) {
        this.count = 0;
        this.bColor = color(255);
      }
    }
  }

  void animate() {
    // Nothing for generic balls atm.
  }
}

/* BALL SUBCLASSES */
class BallLife extends Ball {

  BallLife () {
    super();
    this.bColor = color(255, 0, 0);
    this.collChange = 1;
    LIFES++;
  }

  void collide(Paddle paddle) {
    super.collide(paddle);
    if (this.flag == 1 && !(deadBall.contains(this))) {
      deadBall.add(this);
      LIFES--;
    }
  }

  void animate() {
    switch(this.frame) {
    case 0:
      if ((frames % 90) == 0) {
        noFill();
        strokeWeight(4);
        stroke(this.bColor);
        circle(this.position.x, this.position.y, this.radius + 2);
        //this.radius = BALL_RADIUS + 2;
        this.frame++;
      }
      break;
    case 1:
      //this.radius = BALL_RADIUS;
    default:
      this.frame = 0;
      break;
    }
  }
}

class BallBomb extends Ball {

  BallBomb () {
    super();
    this.bColor = color(75, 75, 75);
    this.collChange = 0;
    BOMBS++;
  }

  void collide(Paddle paddle) {
    super.collide(paddle);
    if (this.flag == 1 && !(deadBall.contains(this))) {
      int quarSize = (balls.size()/4) + 1;
      for (int i = 0; i < quarSize; i++) {
        if (!(balls.get(i) instanceof BallLife)) {
          deadBall.add(balls.get(i));
        }
      }
      deadBall.add(this);
      BOMBS--;
    }
  }

  void animate() {
    switch(this.frame) {
    case 0:
      if ((frames % 30) == 0) {
        this.bColor = color(255, 125, 0);
        this.frame++;
      }
      break;
    case 1:
      this.bColor = color(75, 75, 75);
    default:
      this.frame = 0;
      break;
    }
  }
}

/* WRITING CLASS */
class WriteText {
  String text;
  int x, y, sWidth, tSize;
  color tColor;

  WriteText (String t, int posX, int posY, int sw, int ts, color c) {
    text = t;
    x = posX;
    y = posY;
    sWidth = sw;
    tSize = ts;
    tColor = c;
  }

  void update() {
    fill(this.tColor);
    textSize(this.tSize);
    text(this.text, this.x, this.y);
  }
}

/* INPUTS */
// In case the wheel doesn't work.
void keyPressed() {
  switch(gameState) {
  case "START":
    //delay(500);
    if (key == CODED) {
      if (keyCode == LEFT) {
        resetGame();
        gameState = "PLAY";
      } else if (keyCode == RIGHT) {
        resetGame();
        gameState = "PLAY";
      }
    }
    break;
  case "PLAY":
    if (key == CODED) {
      if (keyCode == LEFT) {
        paddles.get(0).polar.y -= PAD_CHANGE;
        for (Ball ball : balls) {
          if (ball.velocity.mag() > 1) {
            // Decrease velocity magnitude by 10% of all active balls.
            ball.velocity.mult(0.9);
          }
        }
      } else if (keyCode == RIGHT) {
        paddles.get(0).polar.y += PAD_CHANGE;
        for (Ball ball : balls) {
          if (ball.velocity.mag() < MAX_VEL) {
            // Increase velocity magnitude by 10% of all active balls.
            ball.velocity.mult(1.1);
          }
        }
      }
    }
    break;
  default:
    break;
  }
}

// Mouse wheel mapping for record player controller.
void mouseWheel(MouseEvent event) {
  switch(gameState) {
  case "START":
    if (event.getCount() < 0) {
      resetGame();
      gameState = "PLAY";
    } else if (event.getCount() > 0) {
      resetGame();
      gameState = "PLAY";
    }
    break;
  case "PLAY":
    paddles.get(0).polar.y += PAD_CHANGE * event.getCount();
    for (Ball ball : balls) {
      if (event.getCount() < 0) {
        if (ball.velocity.mag() > 1) {
          // Decrease velocity magnitude by 10% of all active balls.
          ball.velocity.mult(0.9);
        }
      } else if (event.getCount() > 0) {
        if (ball.velocity.mag() < 5) {
          // Increase velocity magnitude by 10% of all active balls.
          ball.velocity.mult(1.1);
        }
      }
    }
    break;
  default:
    break;
  }
}


/* FUNCTIONS */
PVector getPolar(PVector vector) {
  PVector polar = new PVector(vector.dist(center), 0);
  polar.x = vector.dist(center);
  // Must add 360 due to negatives. Mod to never exceed 360 for comparison.
  polar.y = (360 + (vector.heading()*180/PI)) % 360;
  return polar;
}

int speedMult() {
  float maxMag = 1;
  for (Ball ball : balls) {
    if (ball.velocity.mag() > maxMag) {
      maxMag = ball.velocity.mag();
    }
  }
  return (int) maxMag;
}

int calcScore(int mult, int balls) {
  int score  = mult * balls;
  return score;
}

void writeText () {
  MULTIPLIER.text = "x" + multi;
  TIMER.text = "" + timer;
  SCORE.text = "" + score;
  MULTIPLIER.update();
  TIMER.update();
  SCORE.update();
}

void resetGame() {
  // Clear arrays.
  paddles.clear();
  balls.clear();
  deadBall.clear();
  // Reset variables.
  PAD_SIZE = 15;
  PAD_CHANGE = (int) PAD_SIZE / 5;
  LIFES = 0;
  BOMBS = 0;
  frames = 0;
  timer = 0;
  multi = 1;
  score = 0;
  // Create new objects.
  paddles.add(new Paddle());
  balls.add(new Ball());
}
