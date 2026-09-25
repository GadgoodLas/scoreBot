import 'package:flutter_test/flutter_test.dart';
import 'package:score_bot/data/services/lineup_parser.dart';

void main() {
  group('LineupParser Tests', () {
    test('parses comma-separated players with "numéro"', () {
      const input = 'numéro 10 Messi, numéro 7 Mbappé, numéro 9 Benzema';
      final players = LineupParser.parse(input);

      expect(players.length, 3);
      expect(players[0].number, 10);
      expect(players[0].name, 'Messi');
      expect(players[1].number, 7);
      expect(players[1].name, 'Mbappé');
      expect(players[2].number, 9);
      expect(players[2].name, 'Benzema');
    });

    test('parses continuous vocal dictation without commas', () {
      const input = 'numéro 10 Messi numéro 7 Mbappé numéro 9 Benzema';
      final players = LineupParser.parse(input);

      expect(players.length, 3);
      expect(players[0].number, 10);
      expect(players[0].name, 'Messi');
      expect(players[1].number, 7);
      expect(players[1].name, 'Mbappé');
      expect(players[2].number, 9);
      expect(players[2].name, 'Benzema');
    });

    test('parses shorthand number and name with commas', () {
      const input = '10 Zidane, 8 Iniesta, 4 Ramos';
      final players = LineupParser.parse(input);

      expect(players.length, 3);
      expect(players[0].number, 10);
      expect(players[0].name, 'Zidane');
      expect(players[1].number, 8);
      expect(players[1].name, 'Iniesta');
      expect(players[2].number, 4);
      expect(players[2].name, 'Ramos');
    });

    test(
      'parses colloquial french dictation ("le 10 Karim et le 7 Cristiano")',
      () {
        const input = 'le 10 Karim et le 7 Cristiano';
        final players = LineupParser.parse(input);

        expect(players.length, 2);
        expect(players[0].number, 10);
        expect(players[0].name, 'Karim');
        expect(players[1].number, 7);
        expect(players[1].name, 'Cristiano');
      },
    );

    test('parses names without numbers', () {
      const input = 'Kylian, Achraf, Marquinhos';
      final players = LineupParser.parse(input);

      expect(players.length, 3);
      expect(players[0].number, isNull);
      expect(players[0].name, 'Kylian');
      expect(players[1].number, isNull);
      expect(players[1].name, 'Achraf');
      expect(players[2].number, isNull);
      expect(players[2].name, 'Marquinhos');
    });

    test('parses single player vocal input', () {
      final p1 = LineupParser.parse('numéro 5 Lucas');
      expect(p1.length, 1);
      expect(p1.first.number, 5);
      expect(p1.first.name, 'Lucas');

      final p2 = LineupParser.parse('7 Mbappé');
      expect(p2.length, 1);
      expect(p2.first.number, 7);
      expect(p2.first.name, 'Mbappé');
    });

    test('handles empty and whitespace input', () {
      expect(LineupParser.parse(''), isEmpty);
      expect(LineupParser.parse('   '), isEmpty);
    });
  });
}
