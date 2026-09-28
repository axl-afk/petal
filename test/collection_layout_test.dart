import 'package:flutter_test/flutter_test.dart';
import 'package:petal/utils/collection_layout.dart';

void main() {
  test('collection artwork grows across phone, tablet, and desktop panes', () {
    final phone = CollectionLayout.cardWidth(320);
    final tablet = CollectionLayout.cardWidth(780);
    final desktop = CollectionLayout.cardWidth(1600);
    final wideDesktop = CollectionLayout.cardWidth(3200);

    expect(CollectionLayout.columns(320), 2);
    expect(phone, greaterThan(140));
    expect(tablet, greaterThan(phone));
    expect(desktop, greaterThan(tablet));
    expect(wideDesktop, greaterThan(desktop));
    expect(CollectionLayout.columns(3200), lessThanOrEqualTo(8));
  });

  test('shelf cards grow with the available window width', () {
    expect(
      CollectionLayout.shelfWidth(400),
      lessThan(CollectionLayout.shelfWidth(1000)),
    );
    expect(
      CollectionLayout.shelfWidth(1000),
      lessThan(CollectionLayout.shelfWidth(3000)),
    );
    expect(
      CollectionLayout.shelfWidth(1920),
      lessThan(CollectionLayout.shelfWidth(3840)),
    );
    expect(CollectionLayout.shelfWidth(3840), lessThanOrEqualTo(560));
  });
}
