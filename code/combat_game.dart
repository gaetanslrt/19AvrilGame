// Code by: @gaetanslrt

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flame_audio/flame_audio.dart';

Color _randomZombieColor(Random random) {
  final colors = [
    Colors.green.shade100,
    Colors.green.shade200,
    Colors.green.shade300,
    Colors.green.shade400,
    Colors.green.shade500,
    Colors.green.shade600,
    Colors.green.shade700,
    Colors.green.shade800,
    Colors.green.shade900,
  ];
  return colors[random.nextInt(colors.length)];
}

class GameOverOverlay extends StatelessWidget {
  final VoidCallback onRestart;
  final int score;
  final int wave;

  const GameOverOverlay({
    super.key,
    required this.onRestart,
    required this.score,
    required this.wave,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black87, // Fond noir
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Game Over',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Score : $score',
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 10),
              Text(
                'Vague atteinte : ${wave - 1}',
                style: const TextStyle(color: Colors.white70, fontSize: 20),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: onRestart,
                child: const Text('Rejouer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BulletComponent extends RectangleComponent {
  final double speed = 2000;
  final bool goingRight;

  BulletComponent({required Vector2 position, required this.goingRight})
    : super(
        position: position.clone(),
        size: Vector2(15, 5),
        paint: Paint()..color = Colors.yellow,
      );

  @override
  void update(double dt) {
    super.update(dt);
    position.x += (goingRight ? 1 : -1) * speed * dt;

    // Supprimer la balle si elle sort de l'écran
    if (position.x < -size.x || position.x > 2000) {
      removeFromParent();
    }
  }
}

class CombatGame extends FlameGame with TapDetector {
  late RectangleComponent gun;

  final Map<RectangleComponent, double> _zombieSpeeds = {};
  late SpriteComponent background;
  int currentWave = 1;
  bool waitingForNextWave = false;
  double waveDelay = 3.0;
  double waveTimer = 0.0;

  late bool lastDirectionRight;

  late Timer zombieSpawnTimer;
  late RectangleComponent player = RectangleComponent(
    position: Vector2(100, 100),
    size: Vector2(50, 50),
    paint: Paint()..color = Colors.grey.shade600,
  );
  late double playerSpeed;
  late double jumpForce;
  late double gravity;
  late List<RectangleComponent> zombies;
  late List<RectangleComponent> bullets; // Liste des projectiles
  int score = 0;
  int playerHealth = 50;
  late bool isJumping;
  late bool isShooting;
  late double playerVelocityX;
  late double playerVelocityY;

  // Contrôles tactiles
  late JoystickComponent joystick;
  late HudButtonComponent jumpButton;
  late HudButtonComponent shootButton;

  // Sol
  late RectangleComponent ground = RectangleComponent(
    position: Vector2(0, size.y - 50),
    size: Vector2(size.x, 50),
    paint: Paint()..color = Colors.grey.shade900,
  );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Charger et démarrer la musique de fond en boucle
    await FlameAudio.bgm.initialize();
    var backgroundMusic = await FlameAudio.loop('music.mp3');
    backgroundMusic.setVolume(0.4); // Ajuster le volume de la musique

    // Charger l'image de fond
    var loadSprite2 = loadSprite('background.png');
    final backgroundImage = await loadSprite2;
    background =
        SpriteComponent()
          ..sprite = backgroundImage
          ..size = size; // Définir la taille pour occuper tout l'écran

    add(background); // Ajouter le background au jeu

    lastDirectionRight = true; // direction par défaut

    zombieSpawnTimer = Timer(2, onTick: spawnZombie, repeat: true);
    zombieSpawnTimer.start();

    // Initialisation du joueur
    player = RectangleComponent(
      position: Vector2(100, size.y - 100),
      size: Vector2(50, 50),
      paint: Paint()..color = Colors.grey.shade600,
    );

    playerSpeed = 200;
    jumpForce = -400;
    gravity = 800;
    playerVelocityX = 0;
    playerVelocityY = 0;
    isJumping = false;
    isShooting = false;

    // Ajout du joueur à la scène
    add(player);
    gun = RectangleComponent(
      size: Vector2(15, 5),
      paint: Paint()..color = Colors.black,
    );
    add(gun);

    zombies = [];
    spawnZombie();

    // Liste des projectiles
    bullets = [];

    // Ajout du sol
    ground = RectangleComponent(
      position: Vector2(0, size.y - 50),
      size: Vector2(size.x, 50),
      paint: Paint()..color = Colors.grey.shade900,
    );
    add(ground);

    // Ajout du joystick et des boutons
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 30, paint: Paint()..color = Colors.grey),
      background: CircleComponent(
        radius: 60,
        paint: Paint()..color = Colors.black26,
      ),
      position: Vector2(120, size.y - 110),
    );

    jumpButton = HudButtonComponent(
      button: CircleComponent(radius: 40, paint: Paint()..color = Colors.red),
      position: Vector2(size.x - 170, size.y - 140),
      onPressed: () => shoot(),
    );
    shootButton = HudButtonComponent(
      button: CircleComponent(
        radius: 30,
        paint: Paint()..color = Colors.orange,
      ),
      position: Vector2(size.x - 90, size.y - 200),
      onPressed: () => jump(),
    );

    add(joystick);
    add(jumpButton);
    add(shootButton);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Limiter la position à gauche et à droite pour que le joueur ne sorte pas de l'écran
    double minX = 0;
    double maxX = size.x - player.size.x;

    if (playerHealth <= 0 && !overlays.isActive('gameOver')) {
      overlays.add('gameOver');
      pauseEngine(); // ❄️ Stoppe l'update du jeu
    }

    // Déplacement du joueur
    playerVelocityX = joystick.relativeDelta.x * playerSpeed;

    if (playerVelocityX != 0) {
      lastDirectionRight = playerVelocityX > 0;
    }

    player.position.x += playerVelocityX * dt;
    player.position.y += playerVelocityY * dt;

    // Limiter les déplacements à gauche et à droite
    if (player.position.x < minX) {
      player.position.x = minX; // Empêche de dépasser la gauche
    }
    if (player.position.x > maxX) {
      player.position.x = maxX; // Empêche de dépasser la droite
    }

    gun.size = Vector2(20, 5); // taille fixe

    if (lastDirectionRight) {
      gun.position = Vector2(
        player.position.x + player.size.x,
        player.position.y + player.size.y / 2 - gun.size.y / 2,
      );
    } else {
      gun.position = Vector2(
        player.position.x - gun.size.x,
        player.position.y + player.size.y / 2 - gun.size.y / 2,
      );
    }

    // Gravité
    if (player.position.y + player.size.y < size.y - 50) {
      playerVelocityY += gravity * dt;
    } else {
      player.position.y = size.y - 50 - player.size.y;
      playerVelocityY = 0;
      isJumping = false;
    }

    // Collisions projectiles/zombies
    bullets.removeWhere((bullet) {
      bool hit = false;
      zombies.removeWhere((zombie) {
        if (bullet.toRect().overlaps(zombie.toRect())) {
          zombie.removeFromParent();
          FlameAudio.play('zombs.mp3');
          score += 1;
          hit = true;
          return true;
        }
        return false;
      });
      if (hit) bullet.removeFromParent();
      return hit;
    });

    // Si tous les zombies sont morts, lancer prochaine vague après un délai
    if (zombies.isEmpty && !waitingForNextWave) {
      waitingForNextWave = true;
      waveTimer = 0.0;
    }

    if (waitingForNextWave) {
      waveTimer += dt;
      if (waveTimer >= waveDelay) {
        waitingForNextWave = false;
        startNextWave();
      }
    }

    for (final zombie in zombies) {
      zombie.position.y = size.y - 100;
      final speed = _zombieSpeeds[zombie] ?? 100;
      final direction = (player.position - zombie.position).normalized();
      zombie.position.x += direction.x * speed * dt;
    }

    checkZombieCollisions();

    if (playerHealth <= 0) {
      gameOver();
    }
  }

  void gameOver() {
    // Ajouter l'overlay Game Over
    overlays.add('gameOver');
  }

  void restartGame() {
    // Reset des variables
    score = 0;
    currentWave = 1;
    waitingForNextWave = false;
    waveTimer = 0.0;
    waveDelay = 3.0;
    playerHealth = 50;
    isJumping = false;
    isShooting = false;
    playerVelocityX = 0;
    playerVelocityY = 0;
    bullets.clear();
    zombies.clear();
    children.whereType<BulletComponent>().forEach((b) => b.removeFromParent());
    children
        .whereType<RectangleComponent>()
        .where((z) => z != player && z != ground)
        .forEach((z) => z.removeFromParent());

    // Réinitialise la position du joueur
    player.position = Vector2(100, size.y - 100);

    add(player);
    add(gun);

    spawnZombie();

    resumeEngine(); // Reprend le moteur du jeu
  }

  void spawnZombie() {
    final random = Random();

    final xPos = random.nextDouble() * (size.x - 90);

    final zombie = RectangleComponent(
      position: Vector2(xPos, size.y - 100),
      size: Vector2(50, 50),
      paint: Paint()..color = _randomZombieColor(random),
    );

    add(zombie);
    zombies.add(zombie);

    // Enregistre la vitesse de ce zombie
    _zombieSpeeds[zombie] =
        50 + random.nextDouble() * 100; // vitesse entre 50 et 150
  }

  void checkZombieCollisions() {
    zombies.removeWhere((zombie) {
      if (zombie.toRect().overlaps(player.toRect())) {
        playerHealth -= 1;

        zombie.removeFromParent();
        return true;
      }
      return false;
    });
  }

  void startNextWave() {
    currentWave += 1;
    for (int i = 0; i < currentWave + 1; i++) {
      spawnZombie();
    }
  }

  // Fonction pour sauter
  void jump() {
    if (!isJumping) {
      playerVelocityY = jumpForce;
      isJumping = true;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '🏆 Vague : $currentWave',
        style: const TextStyle(color: Colors.white, fontSize: 24),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 20));

    final lifePainter = TextPainter(
      text: TextSpan(
        text: '❤️ : $playerHealth',
        style: const TextStyle(color: Colors.red, fontSize: 24),
      ),
      textDirection: TextDirection.ltr,
    );
    lifePainter.layout();
    lifePainter.paint(canvas, const Offset(20, 50));
  }

  // Fonction pour tirer
  void shoot() {
    FlameAudio.play('shoot.mp3'); // Son
    bool goingRight = lastDirectionRight;

    var bullet = BulletComponent(
      position: gun.position + Vector2(gun.size.x / 2, gun.size.y / 2),
      goingRight: goingRight,
    );

    add(bullet);
    bullets.add(bullet);
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);

    // Adapter la taille du sol à la largeur de l'écran
    ground.size.x = canvasSize.x;

    // Le positionner tout en bas de l'écran
    ground.position = Vector2(0, canvasSize.y - ground.size.y);

    // Aussi repositionner le joueur au sol si jamais il flotte après resize
    if (player.position.y + player.size.y > canvasSize.y - ground.size.y) {
      player.position.y = canvasSize.y - ground.size.y - player.size.y;
      playerVelocityY = 0;
      isJumping = false;
    }
  }
}
