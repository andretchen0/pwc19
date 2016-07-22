import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Date;

int NONE = 0;
int CPU = 1; 
int HUMAN = 2;

color[] OWNERS_COLORS = {#666666, #0000FF, #FF0000};
color ACTIVE_COLOR = color(255);

int MAX_PARTICLES = 100;
int MAX_POPULATION_PER_PLANET = 50;

float[] planets_populations;
int[] planets_owners;
float[] planets_positions;
float[] planets_radii;

int[] particles_owners;
float[] particles_positions;
int[] particles_destination_planets;

float particles_step_size_dx = 0.1;

float particles_reproduction_dx = 0.05;

static int source_planet = -1;
static int destination_planet = -1;
boolean is_source_planet_click = true;

float last_frame_sec = 0;
float last_ai_update_sec = 0;
float update_ai_every_x_sec = 1.0;

PGraphics picker_context;

String message = "";
ArrayList<String> messages = new ArrayList<String>();
ArrayList<Integer> messages_conditions = new ArrayList<Integer>();

void messagesResetTimer() {
  messages_timer = sec();
}

boolean messagesOwnPlanetClicked() {
  return source_planet != -1;
}

boolean messagesOtherPlanetClicked() {
  return destination_planet != -1;
}

boolean messagesTwoSecondsPassed() {
  return sec() - messages_timer > 2;
}

void messagesAddMessage(String message, int condition) {
  messages.add(message); 
  messages_conditions.add(condition);
  if (messages.size() == 1) {
    messagesResetTimer();
  }
}

void messagesUpdate() {
  if (messages_conditions.size() == 0) {
    message = ""; 
    return;
  }
  message = messages.get(0);
  int condition = messages_conditions.get(0);
  if (condition == OWN_PLANET_CLICKED && messagesOwnPlanetClicked() ||
    condition == OTHER_PLANET_CLICKED && messagesOtherPlanetClicked() ||
    condition == TWO_SECONDS_PASSED && messagesTwoSecondsPassed()) {
    messagesAdvance();
  }
}

void messagesAdvance() {
  if (messages.size() == 0) {
    message = "";
  } else {
    messages.remove(0);
    messages_conditions.remove(0);
  }
  if (messages.size() > 0) {
    message = messages.get(0);
    messagesResetTimer();
  }
};
int OWN_PLANET_CLICKED = 0;
int OTHER_PLANET_CLICKED = 1;
int TWO_SECONDS_PASSED = 2;
float messages_timer = -1;

HashMap<String, float[]> LETTERS = new HashMap<String, float[]>();
HashMap<String, float[]> LETTERS_DISTANCES = new HashMap<String, float[]>();

float PARTICLE_SIZE = 0.005;

void setup() {
  size(1200, 750);

  planets_populations = new float[]{10.0, 5.0, 5.0, 5.0, 5.0, 10.0};
  planets_owners = new int[]{2, 0, 0, 0, 0, 1};
  planets_positions = new float[]{-0.5, 0.0, 
    -0.25, -0.5, 
    -0.25, 0.5, 
    0.25, -0.5, 
    0.25, 0.5, 
    0.5, 0.0};
  planets_radii = new float[planets_owners.length];

  particles_owners = new int[MAX_PARTICLES];
  particles_positions = new float[2 * MAX_PARTICLES];
  particles_destination_planets = new int[MAX_PARTICLES];

  last_frame_sec = sec();

  picker_context = createGraphics(width, height);

  populateLetterHashTable();

  messagesAddMessage("YOU ARE RED.", TWO_SECONDS_PASSED);
  messagesAddMessage("CLICK YOUR PLANET.", OWN_PLANET_CLICKED);
  messagesAddMessage("CLICK ANOTHER PLANET.", OTHER_PLANET_CLICKED);
  messagesAddMessage("PRESS A KEY.", TWO_SECONDS_PASSED);
  
  background(0);
}

void draw() {
  update();
  render();
}

void update() {
  float now = sec();
  float elapsed_sec = now - last_frame_sec;
  last_frame_sec = now;

  int num_planets = planets_populations.length;
  int owner_seen = NONE;
  int winner = NONE;

  if (source_planet != -1 && planets_owners[source_planet] != HUMAN) source_planet = -1;

  for (int i = 0; i < num_planets; i++) {
    int owner = planets_owners[i];
    if (owner == NONE) continue;
    if (owner_seen == NONE) owner_seen = owner;
    if (owner != owner_seen) break; 
    if (i == num_planets - 1) winner = owner;
  }

  if (winner != NONE) {
    if (winner == HUMAN) {
      messagesAddMessage("YOU WIN!", 2);
    } else {
      messagesAddMessage("YOU LOSE!", 2);
    }
  }

  updateAI();

  for (int i = 0; i < num_planets; i++) {
    if (planets_owners[i] == NONE || planets_populations[i] >= MAX_POPULATION_PER_PLANET) continue;
    planets_populations[i] += planets_populations[i] * particles_reproduction_dx * elapsed_sec;
  }
  for (int i = 0; i < MAX_PARTICLES; i++) {
    if (particles_owners[i] == NONE) continue;
    int planet_i = particles_destination_planets[i];
    float dest_x = planets_positions[planet_i*2];
    float dest_y = planets_positions[planet_i*2+1];
    float pos_x = particles_positions[i*2];
    float pos_y = particles_positions[i*2+1];

    if (dist(pos_x, pos_y, dest_x, dest_y) < particles_step_size_dx * elapsed_sec) {
      if (planets_populations[planet_i] < 1) {
        planets_owners[planet_i] = particles_owners[i];
        planets_populations[planet_i] = 0;
      }
      if (planets_owners[planet_i] != particles_owners[i]) {
        planets_populations[planet_i] --;
      } else {
        planets_populations[planet_i] ++;
      }
      particles_owners[i] = NONE;
    } else {
      PVector v = new PVector(dest_x - pos_x, dest_y - pos_y);
      v.normalize().mult(particles_step_size_dx * elapsed_sec);
      particles_positions[i*2] += v.x;
      particles_positions[i*2+1] += v.y;
    }
  }

  messagesUpdate();
}


void updateAI() {
  if (last_ai_update_sec + update_ai_every_x_sec > sec()) return;
  last_ai_update_sec = sec(); 

  // NOTE: Simple AI
  // Pick the strongest own planet.
  // Pick the weakest non-own planet.
  // Can we own that planet?
  // If yes, do it.

  int num_planets = planets_owners.length;

  ArrayList<Integer> planets_i = new ArrayList<Integer>();
  for (int i = 0; i < num_planets; i++) {
    planets_i.add(i);
  }

  int own_highest_population = -1;
  int own_most_populated_planet = -1;
  int opponent_lowest_population = Integer.MAX_VALUE;
  int opponent_least_populated_planet = -1;

  while (planets_i.size() > 0) {
    int i = planets_i.remove((int)random(planets_i.size()));
    int owner = planets_owners[i];
    int population = (int)planets_populations[i];
    if (owner == CPU && population > own_highest_population) {
      own_most_populated_planet = i;
      own_highest_population = population;
    } else if (owner != CPU && population < opponent_lowest_population) {
      opponent_least_populated_planet = i;
      opponent_lowest_population = population;
    }
  }

  if (own_most_populated_planet == -1 ||
    opponent_least_populated_planet == -1) return;

  if (opponent_lowest_population * 2.25 < own_highest_population) {
    send(own_most_populated_planet, 
      opponent_least_populated_planet);
  }
}

void send(int source, int dest) {
  int num_particles_to_send = (int)(planets_populations[source] * 0.5);
  for (int i = 0; i < MAX_PARTICLES && num_particles_to_send > 0; i++) {
    if (particles_owners[i] != NONE) continue;
    planets_populations[source] --;
    float angle = random(TWO_PI);
    particles_positions[i*2] = planets_positions[source*2] + cos(angle) * planets_radii[source] * 0.5;
    particles_positions[i*2+1] = planets_positions[source*2+1] + sin(angle) * planets_radii[source] * 0.5;

    particles_destination_planets[i] = dest;

    particles_owners[i] = planets_owners[source];
    num_particles_to_send --;
  }
}

void render() {

  pushMatrix();
  translate(width * 0.5, height * 0.5);
  if (width > height) {
    scale(height * 0.75, height * 0.75);
  } else {
    scale(width * 0.75, width * 0.75);
  }

  //background(0);
  stroke(0, 10);
  strokeWeight(3);
  point(0, 0);

  if (source_planet != -1) {
    strokeWeight(planets_radii[source_planet] * 2 + sin(sec()*2) * 0.02 + 0.02);
    stroke(ACTIVE_COLOR);
    point(planets_positions[source_planet*2], planets_positions[source_planet*2+1]);
  }

  if (destination_planet != -1) {
    strokeWeight(planets_radii[destination_planet] * 2 + sin(sec()*2) * 0.02 + 0.02);
    stroke(ACTIVE_COLOR);
    point(planets_positions[destination_planet*2], planets_positions[destination_planet*2+1]);
  }

  if (source_planet != -1 && destination_planet != -1) {
    line(planets_positions[source_planet*2], planets_positions[source_planet*2+1], 
      planets_positions[destination_planet*2], planets_positions[destination_planet*2+1],
      planets_radii[source_planet], planets_radii[destination_planet],
      OWNERS_COLORS[HUMAN], OWNERS_COLORS[planets_owners[destination_planet]],
      2, 0.1);
  }  

  int num_planets = planets_owners.length;

  for (int i = 0; i < num_planets; i++) {
    float curr_radii = lerp(planets_radii[i], getPlanetRadius(i), 0.1);
    planets_radii[i] = curr_radii;
    strokeWeight(curr_radii * 2);
    stroke(OWNERS_COLORS[planets_owners[i]]);
    point(planets_positions[i*2], planets_positions[i*2+1]);
  }

  int num_particles = particles_owners.length;
  for (int i = 0; i < num_particles; i++) {
    if (particles_owners[i] == NONE) continue;
    strokeWeight(PARTICLE_SIZE);
    stroke(OWNERS_COLORS[particles_owners[i]]);
    point(particles_positions[i*2], particles_positions[i*2+1]);
  }

  if (message.length() > 0) {
    pushMatrix();
    scale(0.033, -0.033);
    strokeWeight(PARTICLE_SIZE * 15);
    stroke(255);
    translate(-message.length() * 0.5, 0);
    pointMessage(message);
    popMatrix();
  }

  for (int i = 0; i < num_planets; i++) {
    float population = planets_populations[i];    
    float offset = sec() % TWO_PI;
    float step = TWO_PI / population;
    float radius = planets_radii[i] + 0.02;
    pushMatrix();
    translate(planets_positions[i*2], planets_positions[i*2+1]);
    strokeWeight(PARTICLE_SIZE);
    stroke(OWNERS_COLORS[planets_owners[i]]);
    for (int p = 0; p < population; p++) {
      float angle = step * p;
      float r = cos(angle * 8) * 0.01 + radius;
      point(cos(offset + angle) * r, sin(offset + angle) * r);      
    }
    popMatrix();
  }

  popMatrix();
}

void pointMessage(String message) {
  pointMessage(message, 5);
}

void pointMessage(String message, int num_points) {
  pushMatrix();
  for (int j = 0; j < message.length(); j++) {      
    String s = message.substring(j, j+1);
    float[] lines = LETTERS.get(s);
    if (lines == null) {
      translate(1.1, 0.0);
      continue;
    }      
    float[] distances = getLetterDistances(s);
    float total_distance = distances[distances.length-1];
    float step_size = total_distance / num_points;
    float curr_distance = (sec()) % total_distance;

    for (int i = 0; i < num_points; i++) {
      int curr_letter_distances_i = 0;
      while (curr_letter_distances_i + 1 < distances.length &&
        distances[curr_letter_distances_i + 1] < curr_distance) {
        curr_letter_distances_i++;
      }
      int line_i = curr_letter_distances_i * 2;
      float x = 0.8 * map(curr_distance, distances[curr_letter_distances_i], distances[curr_letter_distances_i+1], lines[line_i], lines[line_i+2]);
      float y = map(curr_distance, distances[curr_letter_distances_i], distances[curr_letter_distances_i+1], lines[line_i+1], lines[line_i+3]);
      point(x, y);
      curr_distance = (curr_distance + step_size) % total_distance;
    }
    translate(1.2, 0.0);
  }
  popMatrix();
}

float getPlanetRadius(int planet_i) {
  return max(0.033, sqrt(planets_populations[planet_i]) * 0.02);
}

void line(float x0, float y0, float x1, float y1, 
          float r1, float r2,
          color color_start, color color_end,
          float points_coeff, float speed_coeff) {
  float d = dist(x0, y0, x1, y1);
  int num_points = max(1, (int) (d / 0.05));  
  float x_diff = x1 - x0;
  float y_diff = y1 - y0;

  float i_step = points_coeff / num_points;
  float offset = (sec() * speed_coeff) % i_step;
  pushMatrix();
  translate(x0, y0);
  float percent_complete = 0;
  for (float i = 0.0; i < 1.0 - offset; i += i_step) {
    percent_complete = i/(1.0 - offset);
    strokeWeight(lerp(r1*2, r2*2, percent_complete));
    stroke(lerpColor(color_start, color_end, percent_complete), 10);
    point(lerp(0, x_diff, i + offset), lerp(0, y_diff, i + offset));
  }
  popMatrix();
}

int pickPlanet() {
  picker_context.beginDraw();
  picker_context.background(255);
  int num_planets = planets_owners.length; 

  picker_context.translate(width * 0.5, height * 0.5);
  if (width > height) {
    picker_context.scale(height * 0.75, height * 0.75);
  } else {
    picker_context.scale(width * 0.75, width * 0.75);
  }

  for (int i = 0; i < num_planets; i++) {
    picker_context.strokeWeight(max(0.1, planets_radii[i] * 2));    
    //NOTE: important! Planets limited to 255.
    picker_context.stroke(i);
    picker_context.point(planets_positions[i*2], planets_positions[i*2+1]);
  }
  picker_context.loadPixels();
  picker_context.endDraw();
  int planet_i = round(brightness(picker_context.pixels[mouseX + mouseY * width]));
  if (planet_i < 255) {
    return planet_i;
  }
  return -1;
}

void mouseClicked() {
  int planet_i = pickPlanet();
  if (planet_i < 0 || planet_i >= planets_owners.length) return;
  if (planets_owners[planet_i] != HUMAN) {
    destination_planet = planet_i;
    is_source_planet_click = true;
    return;
  }
  if (is_source_planet_click) {
    source_planet = planet_i;
  } else {
    if (planet_i == source_planet) {
      destination_planet = -1;
      return;
    }
    destination_planet = planet_i;
  }
  is_source_planet_click = !is_source_planet_click;
}

void keyPressed() {
  if (source_planet > -1 && destination_planet > -1) {
    send(source_planet, destination_planet);
  }
  message = "" + Character.toUpperCase(key);
}

float sec() {
  return millis() * 0.001;
}

float[] getLetterDistances(String str) {
  float[] distances = LETTERS_DISTANCES.get(str);
  if (distances != null) return distances;
  float[] letter_coords = LETTERS.get(str);
  if (letter_coords == null) return null;
  float distance = 0;
  distances = new float[(int)((letter_coords.length - 2)* 0.5) + 1];
  for (int i = 0; i < letter_coords.length-2; i+=2) {
    distance += dist(letter_coords[i], letter_coords[i+1], 
      letter_coords[i+2], letter_coords[i+3]);
    distances[(int)(i * 0.5) + 1] = distance;
  }
  LETTERS_DISTANCES.put(str, distances);
  return distances;
}


float[] A = {0, 0, 
  0.5, 1.0, 
  0.75, 0.2, 
  0.25, 0.2, 
  1.0, 0.0};
float[] B = {0.0, 0.0, 0.0, 1.0, 
  0.0, 1.0, 0.75, 1.0, 
  1.0, 0.8, 1.0, 0.8, 
  0.25, 0.6, 0.8, 0.6, 
  1.0, 0.4, 1.0, 0.2, 
  0.75, 0.0, 0.0, 0.0};
float[] C = {1.0, 0.0, 0.25, 0.0, 
  0.0, 0.2, 0.0, 0.8, 
  0.25, 1.0, 0.75, 1.0};
float[] D = {0.0, 0.0, 0.0, 1.0, 
  0.0, 1.0, 0.75, 1.0, 
  0.75, 1.0, 1.0, 0.8, 
  1.0, 0.8, 1.0, 0.2, 
  1.0, 0.2, 0.8, 0.0, 
  0.8, 0.0, 0.2, 0.0};
float[] E = {
  1.0, 0.0, 
  0.0, 0.0, 
  0.0, 0.6, 
  0.5, 0.6, 
  0.0, 0.6, 
  0.0, 1.0, 
  1.0, 1.0};
float[] F = {0.0, 0.0, 0.0, 1.0, 
  0.0, 0.6, 
  0.5, 0.6, 
  0.0, 0.6, 
  0.0, 1.0, 
  1.0, 1.0};
float[] G = {0.5, 0.6, 1.0, 0.6, 
  1.0, 0.6, 1.0, 0.0, 
  1.0, 0.0, 0.25, 0.0, 
  0.0, 0.2, 0.0, 0.8, 
  0.25, 1.0, 0.75, 1.0};
float[] H = {0.0, 0.0, 0.0, 1.0, 
  0.0, 0.6, 0.75, 0.6, 
  1.0, 0.0, 1.0, 1.0};
float[] I = {0.5, 0.0, 0.5, 1.0};
float[] J = {0.5, 1.0, 1.0, 1.0, 
  1.0, 1.0, 1.0, 0.2, 
  0.75, 0.0, 0.25, 0.0, 
  0.25, 0.0, 0.0, 0.2};
float[] K = {0.0, 0.0, 0.0, 1.0, 
  0.0, 0.6, 
  0.75, 1.0, 0.25, 0.6, 
  1.0, 0.0};
float[] L = {1.0, 0.0, 0.0, 0.0, 
  0.0, 0.0, 0.0, 1.0};
float[] M = {0.0, 0.0, 0.0, 1.0, 
  0.25, 0.8, 0.5, 0.6, 
  0.5, 0.6, 0.75, 0.8, 
  1.0, 1.0, 1.0, 0.0};
float[] N = {0.0, 0.0, 0.0, 1.0, 
  0.25, 0.8, 1.0, 0.2, 
  1.0, 0.0, 1.0, 1.0};
float[] O = {0.0, 0.2, 0.0, 0.8, 
  0.25, 1.0, 0.75, 1.0, 
  1.0, 0.8, 1.0, 0.2, 
  0.75, 0.0, 0.25, 0.0, 0.0, 0.2};
float[] P = {0.0, 0.0, 0.0, 1.0, 
  0.0, 1.0, 0.75, 1.0, 
  1.0, 0.8, 1.0, 0.6, 
  0.75, 0.4, 0.25, 0.4};
float[] Q = {0.0, 0.2, 
  0.0, 0.8, 
  0.25, 1.0, 
  0.75, 1.0, 
  1.0, 0.8, 
  1.0, 0.2, 
  0.75, 0.0, 
  0.5, 0.5, 
  0.75, 0.0, 
  0.25, 0.0, 
  0.0, 0.2};
float[] R = {0.0, 0.0, 0.0, 1.0, 
  0.0, 1.0, 0.75, 1.0, 
  1.0, 0.8, 1.0, 0.6, 
  0.75, 0.4, 0.25, 0.4, 
  0.75, 0.2, 1.0, 0.0};
float[] S = {0.0, 0.0, 0.75, 0.0, 
  1.0, 0.2, 1.0, 0.4, 
  0.75, 0.6, 0.25, 0.6, 
  0.25, 0.6, 0.0, 0.8, 
  0.25, 1.0, 0.75, 1.0};
float[] T = {0.0, 1.0, 1.0, 1.0, 
  0.5, 1.0, 0.5, 0.0};
float[] U = {0.0, 1.0, 0.0, 0.2, 
  0.25, 0.0, 1.0, 0.0, 
  1.0, 0.0, 1.0, 1.0};
float[] V = {0.0, 1.0, 0.5, 0.0, 
  0.5, 0.0, 1.0, 1.0};
float[] W = {0.0, 1.0, 0.0, 0.0, 
  0.25, 0.2, 0.5, 0.4, 
  0.5, 0.4, 0.75, 0.2, 
  1.0, 0.0, 1.0, 1.0};
float[] X = {0.0, 0.0, 0.5, 0.4, 
  0.5, 0.4, 1.0, 0.0, 
  0.0, 1.0, 0.5, 0.6, 
  0.5, 0.6, 1.0, 1.0};
float[] Y = {0.0, 1.0, 
  0.5, 0.6, 0.5, 0.0, 
  0.5, 0.6, 1.0, 1.0};
float[] Z = {1.0, 0.0, 0.0, 0.0, 
  0.0, 0.0, 0.0, 0.2, 
  0.0, 0.2, 1.0, 1.0, 
  1.0, 1.0, 0.0, 1.0};
float [] ZERO = {0.0, 0.2, 0.0, 0.8, 
  0.25, 1.0, 0.75, 1.0, 
  1.0, 0.8, 1.0, 0.2, 
  0.75, 0.0, 0.25, 0.0, 
  0.0, 0.2, 1.0, 0.8};  
float[] ONE = {0.25, 0.8, 0.5, 1.0, 0.5, 0.0, 0.5, 0.0};
float[] TWO = {1.0, 0.0, 0.0, 0.0, 
  0.0, 0.0, 1.0, 0.6, 
  1.0, 0.6, 1.0, 0.8, 
  0.75, 1.0, 0.25, 1.0, 
  0.0, 0.8, 0.0, 0.8};
float[] THREE = {0.0, 0.2, 0.0, 0.2, 
  0.25, 0.0, 0.75, 0.0, 
  1.0, 0.2, 1.0, 0.4, 
  0.5, 0.6, 0.75, 0.6, 
  1.0, 0.8, 1.0, 0.8, 
  0.75, 1.0, 0.25, 1.0};
float[] FOUR = {0.25, 0.8, 0.0, 0.4, 
  0.0, 0.4, 1.0, 0.4, 
  0.75, 1.0, 0.75, 0.0};  
float[] FIVE = {0.0, 0.0, 0.75, 0.0, 
  1.0, 0.2, 1.0, 0.4, 
  0.0, 0.6, 
  0.25, 1.0, 1.0, 1.0};
float[] SIX = {1.0, 0.6, 0.25, 0.6, 
  0.0, 0.4, 0.0, 0.2, 
  0.25, 0.0, 0.75, 0.0, 
  1.0, 0.25, 1.0, 0.75, 
  0.75, 1.0, 0.25, 1.0};
float[] SEVEN = {0.0, 1.0, 1.0, 1.0, 
  1.0, 1.0, 0.5, 0.6, 
  0.5, 0.6, 0.5, 0.0};
float[] EIGHT = {0.0, 0.2, 
  0.5, 0.0,
  1.0, 0.2,
  0.0, 0.8, 
  0.5, 1.0,
  1.0, 0.8,
  0.0, 0.2};
float[] NINE = {1.0, 0.4, 0.25, 0.4, 
  0.0, 0.6, 0.0, 0.8, 
  0.25, 1.0, 0.75, 1.0, 
  1.0, 0.75, 1.0, 0.25, 
  0.75, 0.0, 0.25, 0.0};
float[] PERIOD = {0.0, 0.0, 0.25, 0.0};
float[] QUESTION = {0.25, 0.2, 0.25, 0.4, 
  0.0, 1.0, 0.75, 1.0, 
  1.0, 0.8, 1.0, 0.6, 
  0.75, 0.4, 0.25, 0.4, 
  0.25, 0.0, 0.25, 0.0};
float[] COMMA = {0.25, 0.0, 0.0, -0.2};
float[] APOSTROPHE = {0.75, 1.0, 0.25, 0.8};
float[] EXCLAMATION = {0.5, 0.4, 
  0.75, 0.2, 
  0.5, 0.0, 
  0.25, 0.2, 
  0.5, 0.4, 
  0.5, 1.0, 
};
float[] FORWARD_SLASH = {0.0, 0.0, 1.0, 1.0}; 
float[] HYPHEN = {0.25, 0.6, 0.75, 0.6};

void populateLetterHashTable() {
  LETTERS.put("A", A);
  LETTERS.put("B", B);
  LETTERS.put("C", C);
  LETTERS.put("D", D);
  LETTERS.put("E", E);
  LETTERS.put("F", F);
  LETTERS.put("G", G);
  LETTERS.put("H", H);
  LETTERS.put("I", I);
  LETTERS.put("J", J);
  LETTERS.put("K", K);
  LETTERS.put("L", L);
  LETTERS.put("M", M);
  LETTERS.put("N", N);
  LETTERS.put("O", O);
  LETTERS.put("P", P);
  LETTERS.put("Q", Q);
  LETTERS.put("R", R);
  LETTERS.put("S", S);
  LETTERS.put("T", T);
  LETTERS.put("U", U);
  LETTERS.put("V", V);
  LETTERS.put("W", W);
  LETTERS.put("X", X);
  LETTERS.put("Y", Y);
  LETTERS.put("Z", Z);
  LETTERS.put("0", ZERO);
  LETTERS.put("1", ONE);  
  LETTERS.put("2", TWO);  
  LETTERS.put("3", THREE);
  LETTERS.put("4", FOUR);
  LETTERS.put("5", FIVE);
  LETTERS.put("6", SIX);
  LETTERS.put("7", SEVEN);
  LETTERS.put("8", EIGHT);  
  LETTERS.put("9", NINE);
  LETTERS.put(".", PERIOD);
  LETTERS.put("?", QUESTION); 
  LETTERS.put(",", COMMA);
  LETTERS.put("'", APOSTROPHE);  
  LETTERS.put("!", EXCLAMATION);
  LETTERS.put("/", FORWARD_SLASH);
  LETTERS.put("-", HYPHEN);
}