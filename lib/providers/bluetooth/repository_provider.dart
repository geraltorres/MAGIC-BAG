import 'package:magic_bag/core/mocks/mock_bluetooth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/repositories/bag_repository.dart';
import '../../core/di/service_locator.dart';

part 'repository_provider.g.dart';

@riverpod
BagRepository bagRepository(BagRepositoryRef ref) {
  const bool useMock = true; // <--- Cambia esto a 'false' cuando estés en la moto
  if (useMock) {
    return MockBluetoothRepository();
  } else {
    return getIt<BagRepository>(); // Tu repo real con FlutterBluePlus
  }
}
