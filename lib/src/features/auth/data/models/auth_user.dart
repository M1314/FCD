import 'package:fcd_app/src/core/utils/json_utils.dart';

class AuthUser {
  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
    this.phone = '',
    this.lastName = '',
    this.membersChat = false,
    this.shippingAddressesJson = '',
  });

  final int id;
  final String name;
  final String email;
  final String type;
  final String phone;
  final String lastName;
  final bool membersChat;
  final String shippingAddressesJson;

  bool get isAdmin => type == 'administrator';

  factory AuthUser.fromLoginResponse(Map<String, dynamic> payload) {
    final result = asMap(payload['Result']);

    final adminRaw = asMap(result['administrator']);
    if (adminRaw.isNotEmpty) {
      return AuthUser(
        id: readInt(adminRaw, <String>['idAdministrador']),
        name: readString(adminRaw, <String>['nombre']),
        email: readString(adminRaw, <String>['email']),
        type: 'administrator',
        lastName: readString(adminRaw, <String>['apellidos']),
      );
    }

    final userRaw = asMap(result['user']);
    return AuthUser(
      id: readInt(userRaw, <String>['idusuarioCliente']),
      name: readString(userRaw, <String>['nombre']),
      email: readString(userRaw, <String>['email']),
      type: 'user',
      phone: readString(userRaw, <String>['telefono']),
      lastName: readString(userRaw, <String>['apellidos']),
      membersChat: readBool(userRaw, <String>['membersChat']),
      shippingAddressesJson: readString(userRaw, <String>[
        'direccionesEntrega',
      ]),
    );
  }

  factory AuthUser.fromRefreshResponse(Map<String, dynamic> payload) {
    final adminRaw = asMap(payload['administrator']);
    if (adminRaw.isNotEmpty) {
      return AuthUser(
        id: readInt(adminRaw, <String>['idAdministrador']),
        name: readString(adminRaw, <String>['nombre']),
        email: readString(adminRaw, <String>['email']),
        type: 'administrator',
        lastName: readString(adminRaw, <String>['apellidos']),
      );
    }

    final userRaw = asMap(payload['user']);
    return AuthUser(
      id: readInt(userRaw, <String>['idusuarioCliente']),
      name: readString(userRaw, <String>['nombre']),
      email: readString(userRaw, <String>['email']),
      type: 'user',
      phone: readString(userRaw, <String>['telefono']),
      lastName: readString(userRaw, <String>['apellidos']),
      membersChat: readBool(userRaw, <String>['membersChat']),
      shippingAddressesJson: readString(userRaw, <String>[
        'direccionesEntrega',
      ]),
    );
  }
}
