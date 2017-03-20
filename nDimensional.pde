// nDimensional

//import com.jogamp.opengl.*;  // new jogl - 3.0b7
import java.text.SimpleDateFormat;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.Set;

static final int DIMENSION = 6;
static final int NUMBER_OF_LINES = 0;
static final int NUMBER_OF_FACES = 20;
static final boolean ADDITIVE = false;

static final int COUNT = (1 << DIMENSION);
static final int ROTATIONS = DIMENSION;
static final int SCALE = 200;
static final float SZ = .5;
static final float MAX_ANGLE = .05;
static final float DEPTH = 6.0;
boolean video = false;
SimpleDateFormat format = new SimpleDateFormat("yyyyMMdd_HHmmss");

Rotation[] rotations = new Rotation[ROTATIONS];
PointN[] points = new PointN[COUNT];
PVector[] twoD = new PVector[COUNT];
List<LineN> lines = new ArrayList<LineN>();
HashMap<String, Face> faces = new HashMap<String, Face>();

void setup() {

  size(1000, 700, P2D);
  frameRate(20);
  
  // points
  for (int i = 0 ; i < COUNT ; i++) {
    points[i] = new PointN(DIMENSION, i);
  }

  // all lines
  for (int i = 0; i < COUNT; i++) { //<>//
    for (int d = 0 ; d < DIMENSION ; d++) {
      addLine(i, i ^ (0x1 << d));
    }
  }
  println("There are " + lines.size() + " lines");

  // limit lines
  if (lines.size() > NUMBER_OF_LINES) {
    // shuffle and crop
    Collections.shuffle(lines);
    lines = lines.subList(0, NUMBER_OF_LINES);
    println("Lines cropped to " + lines.size() + " lines");
  }

  // all faces
  for (int i = 0 ; i < DIMENSION ; i++) {
    for (int j = i + 1 ; j < DIMENSION ; j++) {
      for (PointN point : points) {
        String faceName = point.calcFaceName(i, j);
        if (faces.get(faceName) == null) {
          faces.put(faceName, new Face());
        }
        faces.get(faceName).add(point.index);
      }
    }
  }
  println("There are " + faces.size() + " faces");

  // limit faces
  if (faces.size() > NUMBER_OF_FACES) {
    // shuffle and crop
    Set<String> keys = faces.keySet(); //<>//
    List<String> keyList = new ArrayList<String>(keys);
    Collections.shuffle(keyList);
    keyList = keyList.subList(NUMBER_OF_FACES, keyList.size());
    println("Faces be deleted " + keyList.size());
    for (String key : keyList) {
      faces.remove(key);
    }
    keys = null;
    keyList = null;
    println("There are now " + faces.size() + " faces");
  }

  // disable unused points

  // initialise rotations
  initAngles();
}

void draw() {

  background(0);
  //smooth();

  //if (ADDITIVE) {
  //  // PJOGL 2.2.1, 30b7
  //  GL gl = ((PJOGL)beginPGL()).gl.getGL();

  //  // additive blending
  //  gl.glEnable(GL.GL_BLEND);
  //  gl.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE);
  //  gl.glDisable(GL.GL_DEPTH_TEST);
  //}

  translate(width / 2, height / 2);
  scale(SCALE, SCALE);

  // update angles
  for (int i = 0 ; i < ROTATIONS ; i++) {
    rotations[i].update();
  }

  // transform each (enabled) point - apply n-2 lots of perspective losing a dimension each time
  for (int i = 0; i < COUNT; i++) {
    if (points[i].enabled) {
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
  }

  // draw all lines
  for (int i = 0; i < lines.size(); i++) {
    LineN l = (LineN)lines.get(i);
    strokeWeight(10.0 / SCALE);
    stroke(l.c);
//    line(twoD[l.p0].x, twoD[l.p0].y, twoD[l.p1].x, twoD[l.p1].y);
  }

  // draw all faces
  for (Face face : faces.values()) {
    face.draw();
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
  boolean enabled;

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
    enabled = true;
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

  // used to generate a name for the face, for hashing purposes.
  // things on the same face, where everything but points i and j are the same
  // should get the same face name.
  // facenames are like -+XX, X++X, should have two Xs and +/- to indicate sign. 
  String calcFaceName(int i, int j) {
    StringBuilder s = new StringBuilder();
    for (int d = 0 ; d < DIMENSION ; d++) {
      if (d == i || d == j) {
        s.append("X");
      } else if (p[d] == -SZ) {
        s.append("-");
      } else {
        s.append("+");
      }
    }
    //println("Point[" + index + "] FaceName[" + s.toString() + "]");
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

void keyPressed() {
  if (key == 's') {
    saveFrame("frame####.png");
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
    //printMatrix();
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

class Face {
  int MINCOL = 0;
  int MAXCOL = 256;
  int TRANS = 200;
  ArrayList<Integer> points = new ArrayList<Integer>(4);
  color c;
  boolean display = false;
  
  Face() {
    c = randomColour();
  }
  
  void add(int i) {
    points.add(i);
  }

  // how to make sure this is a square and not a bowtie
  // A-B A-D A-B
  //  /  | | | |
  // C-D B-C D-C
  
  void draw() {
    beginShape(QUAD);
    fill(c);
    noStroke();
    vertex(twoD[points.get(0)].x, twoD[points.get(0)].y);
    vertex(twoD[points.get(1)].x, twoD[points.get(1)].y);
    vertex(twoD[points.get(3)].x, twoD[points.get(3)].y);
    vertex(twoD[points.get(2)].x, twoD[points.get(2)].y);
    endShape(CLOSE);
  }
  
  color randomColour() {
    color c;
    c = color(random(MINCOL, MAXCOL), random(MINCOL, MAXCOL), random(MINCOL, MAXCOL), TRANS);
    c = color(random(MINCOL, MAXCOL));
    c = 128 * (int)random(3);
    c = color(c, c, c);
    c = 0xff000000 | 0xff << (8 * (int)random(3));
    return c;
  }
}