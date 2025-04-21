// Code by: @gaetanslrt

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'combat_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forcer le mode paysage
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Activer le mode fullscreen
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  runApp(
    GameWidget(
      game: CombatGame(),
      overlayBuilderMap: {
        'gameOver': (context, game) {
          final combatGame = game as CombatGame;
          return GameOverOverlay(
            score: combatGame.score,
            wave: combatGame.currentWave,
            onRestart: () {
              combatGame.restartGame();
              game.overlays.remove('gameOver');
            },
          );
        },
      },
    ),
  );
}
