import 'package:fcd_app/src/features/catalog/presentation/catalog_page.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../test_helpers/fake_api_client.dart';

void main() {
  testWidgets(
    'does not render lessons-count tags in catalog course cards',
    (tester) async {
      final session = SessionController.forTesting(
        apiClient: FakeApiClient(
          onGet: (path, {queryParameters, authenticated = false}) async {
            if (path == '/course/All/0') {
              return <String, dynamic>{
                'intResponse': 200,
                'Result': <String, dynamic>{
                  'cursos': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'idcurso': 1,
                      'nombre': 'Curso de Prueba',
                      'subtitulo': 'Subtitulo',
                      'descripcion': 'Descripcion',
                      'icono': '',
                      'portada': '',
                      'total_lecciones_curso': 0,
                      'idCategoria': 1,
                    },
                  ],
                },
              };
            }
            return <String, dynamic>{'intResponse': 200};
          },
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<SessionController>.value(
          value: session,
          child: const MaterialApp(home: Scaffold(body: CatalogPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Curso de Prueba'), findsOneWidget);
      expect(find.textContaining('lecciones'), findsNothing);
    },
  );
}
