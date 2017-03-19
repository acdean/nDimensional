// nDimensional

static final int DIMENSION = 3;
static final int COUNT = (1 << DIMENSION);
static final int ROTATIONS = DIMENSION;
static final int SCALE = 60;
static final float SZ = .5;
static final float MAX_ANGLE = .05;
static final float DEPTH = 6.0;
boolean video = false;

Rotation[] rotations = new Rotation[ROTATIONS];

PointN[] points = new PointN[COUNT];
PVector[] twoD = new PVector[COUNT];
ArrayList lines = new ArrayList();

void setup() {

  size(640, 360, P3D);
  frameRate(20);
  
  // points
  for (int i = 0 ; i < COUNT ; i++) {
    points[i] = new PointN(DIMENSION, i);
  }

  // lines
  for (int i = 0; i < COUNT; i++) { //<>//
    for (int d = 0 ; d < DIMENSION ; d++) {
      addLine(i, i ^ (0x1 << d));
    }
  }

  initAngles();
}

void draw() {

  background(0);
  //smooth();

  translate(width / 2, height / 2);
  scale(SCALE, SCALE);

  // update angles
  for (int i = 0 ; i < ROTATIONS ; i++) {
    rotations[i].update();
  }

  // transform each point - apply 3 lots of perspective losing a dimension each time
  for (int i = 0; i < COUNT; i++) {
    PointN p = points[i].copy();
    // apply all rotations
    for (int r = 0 ; r < ROTATIONS ; r++) {
      p = rotations[r].rotate(p);
    }
    // all perspectives (reduce to 2d so 1 less than DIMENSION)
    for (int d = 0 ; d < DIMENSION - 2 ; d++) {
      p.perspective();
    }
    // store the 2d result
    twoD[i] = new PVector(p.x(), p.y());
  }

  // draw all lines
  LineN l = null;
  for (int i = 0; i < lines.size(); i++) {
    l = (LineN)lines.get(i);
    strokeWeight(10.0 / SCALE);
    stroke(l.c);
    line(twoD[l.p0].x, twoD[l.p0].y, twoD[l.p1].x, twoD[l.p1].y);
  }
  
  if (video) {
    saveFrame("frame_#####.png");
    if (frameCount > 500) {
      noLoop();
    }
  }
}


// n dimensional point
// each is a combination of n +/- 1
class PointN {
  float[] p;
  int dim;
  int index;

  PointN(int dim) {
    this(dim, -1);
  }
  PointN(int dim, int index) {
    this.dim = dim;
    this.index = index;
    p = new float[dim];
    if (index != -1) {
      for (int d = 0 ; d < dim ; d++) {
        if ((index & (0x1 << d)) == 0) {
          p[d] = -SZ;
        } else {
          p[d] = SZ;
        }
      }
    }
    if (index != 0) {
      //println(this);
    }
  }

  float x() {
    return p[0];
  }

  float y() {
    return p[1];
  }

  PointN copy() {
    PointN newP = new PointN(dim);
    for (int d = 0 ; d < dim ; d++) {
      newP.p[d] = this.p[d];
    }
    return newP;
  }

  // reduces perspective
  // d = 4 reduces a 4d point to a 3d shape
  // NB this is destructive - don't use on the originals
  PointN perspective() {
    float factor = DEPTH / (DEPTH - p[dim - 1]);
    for (int i = 0 ; i < dim - 1 ; i++) {
      p[i] *= factor;
    }
    // reduce the dimension
    dim--;
    return this;
  }
  
  @Override
  String toString() {
    StringBuilder s = new StringBuilder();
    for (int i = 0 ; i < dim ; i++) {
      s.append(p[i]);
      s.append(", ");
    }
    return s.toString();
  }
}

private void addLine(int i, int j) {
  // only add those that haven't already been added
  // ie don't add b->a if a->b is already there
  if (i < j) {
    if (random(1000) < 1000) { // new
      lines.add(new LineN(i, j));
    }
  }
}

void initAngles() {
  for (int i = 0 ; i < ROTATIONS ; i++) {
    rotations[i] = new Rotation(0);
  }
}

public class LineN {
  int p0, p1;
  color c;

  public LineN(int p0, int p1) {
    this.p0 = p0;
    this.p1 = p1;
    c = color(127 + random(128), 127 + random(128), 127 + random(128));
  }
}

void mouseReleased() {
  loop();
}

void mousePressed() {
  initAngles();
  //  noLoop();
  saveFrame("nDimension_####.png");
}

class Rotation {
  float[][] matrix = new float[DIMENSION][DIMENSION];
  int axis1, axis2;
  float angle;
  float delta;
  
  public Rotation(float angle) {
    this.angle = angle;
    delta = random(-MAX_ANGLE, MAX_ANGLE);
    axis1 = (int)random(DIMENSION);
    do {
      axis2 = (int)random(DIMENSION);
    } while (axis2 == axis1);
    // set leading diagonal
    for (int i = 0; i < DIMENSION; i++) {
      if (i != axis1 && i != axis2) {
        matrix[i][i] = 1;
      }
    }
    angle += delta;
    setAngle(angle);
    printMatrix();
  }

  void update() {
    angle += delta;
    setAngle(angle);
  }

  void setAngle(float angle) {
    this.angle = angle;
    float c = cos(angle);
    float s = sin(angle);
    matrix[axis1][axis1] = c;
    matrix[axis1][axis2] = -s;
    matrix[axis2][axis1] = s;
    matrix[axis2][axis2] = c;
  }

  // matrix multiply
  // only works on points of DIMENSIONS dimensions
  public PointN rotate(PointN p) {
    //println("rotate");
    PointN pout = new PointN(p.dim);
    //println("rotate in:" + pout);
    for (int i = 0 ; i < DIMENSION ; i++) {
      for (int j = 0 ; j < DIMENSION ; j++) {
        pout.p[i] += p.p[j] * matrix[j][i];
      }
    }
    return pout;
  }
  
  void printMatrix() {
    for (int y = 0 ; y < DIMENSION ; y++) {
      for (int x = 0 ; x < DIMENSION ; x++) {
        print(matrix[x][y] + "\t");
      }
      println();
    }
    println();
    println();
  }
}