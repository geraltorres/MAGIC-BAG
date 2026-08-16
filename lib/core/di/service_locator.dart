import 'package:get_it/get_it.dart';
import '../../domain/repositories/bag_repository.dart';
import '../../data/repositories/bluetooth_bag_repository_impl.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // Registramos como LazySingleton para que la instancia del Bluetooth
  // solo se cree cuando realmente se necesite (ahorro de batería en la moto)
  getIt.registerLazySingleton<BagRepository>(
    () => BluetoothBagRepositoryImpl(),
  );
}
