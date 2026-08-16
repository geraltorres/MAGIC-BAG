import '../../core/utils/command_parser.dart';

class ProcessVoiceCommand {
  String execute(String text) {
    // El caso de uso solo orquesta la llamada al parser del core
    return CommandParser.parse(text);
  }
}
