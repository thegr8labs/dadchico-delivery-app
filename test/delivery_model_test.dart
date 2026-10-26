import 'package:delivery_app/models/delivery_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads customer instructions from the populated order', () {
    final d = DeliveryModel.fromJson({
      '_id': 'd1',
      'status': 'ASSIGNED',
      'orderId': {'_id': 'o1', 'orderNumber': 'DC-1', 'customerNotes': '  Gate code 2244  '},
    });
    expect(d.orderId.customerNotes, 'Gate code 2244');
  });

  test('customer instructions default to empty', () {
    final d = DeliveryModel.fromJson({'_id': 'd1', 'status': 'ASSIGNED', 'orderId': 'o1'});
    expect(d.orderId.customerNotes, '');
  });
}
