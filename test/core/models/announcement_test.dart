import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/core/models/announcement.dart';

final _now = DateTime.utc(2026, 11, 26, 12);
DateTime _day(int offset) => _now.add(Duration(days: offset));

Announcement _item(
  String id, {
  bool pinned = false,
  DateTime? createdAt,
  bool noCreatedAt = false,
  DateTime? expiresAt,
  bool published = true,
  List<String> audience = Announcement.roles,
}) =>
    Announcement(
      id: id,
      title: 'Title $id',
      body: '',
      audience: audience,
      pinned: pinned,
      expiresAt: expiresAt,
      createdAt: noCreatedAt ? null : (createdAt ?? _day(-1)),
      createdByName: '',
      published: published,
    );

void main() {
  test('parses a document and keeps line breaks in the body', () {
    final item = Announcement.fromMap('a1', {
      'title': '  Bayana update ',
      'body': 'Line one\nLine two\n',
      'audience': ['Parent', 'teacher', 'circle_member', 'parent'],
      'pinned': true,
      'expires_at': Timestamp.fromDate(_day(3)),
      'created_at': Timestamp.fromDate(_day(-2)),
      'created_by_name': 'Office',
      'status': 'published',
    })!;
    expect(item.title, 'Bayana update');
    expect(item.body, 'Line one\nLine two');
    expect(item.audience, ['teacher', 'parent']);
    expect(item.pinned, isTrue);
    expect(item.expiresAt!.isAtSameMomentAs(_day(3)), isTrue);
    expect(item.published, isTrue);
  });

  test('drops a document without a title; unknown status is not published', () {
    expect(Announcement.fromMap('x', {'body': 'no title'}), isNull);
    expect(
        Announcement.fromMap('y', {'title': 't', 'status': 'draft'})!.published,
        isFalse);
  });

  test('expired and archived announcements are not active', () {
    expect(_item('open').isActive(_now), isTrue);
    expect(_item('future', expiresAt: _day(1)).isActive(_now), isTrue);
    expect(_item('past', expiresAt: _day(-1)).isActive(_now), isFalse);
    expect(_item('now', expiresAt: _now).isActive(_now), isFalse);
    expect(_item('gone', published: false).isActive(_now), isFalse);
  });

  test('lists pinned first, then newest first, for the given role only', () {
    final list = activeAnnouncements([
      _item('old', createdAt: _day(-5)),
      _item('new', createdAt: _day(-1)),
      _item('pinnedOld', pinned: true, createdAt: _day(-9)),
      _item('pinnedNew', pinned: true, createdAt: _day(-3)),
      _item('parentsOnly', audience: ['parent'], createdAt: _day(0)),
      _item('expired', expiresAt: _day(-1)),
      _item('undated', noCreatedAt: true),
    ], 'teacher', _now);
    expect(list.map((e) => e.id),
        ['pinnedNew', 'pinnedOld', 'new', 'old', 'undated']);
  });

  test('pops up the newest unseen pinned announcement', () {
    final list = activeAnnouncements([
      _item('plain'),
      _item('p1', pinned: true, createdAt: _day(-4)),
      _item('p2', pinned: true, createdAt: _day(-2)),
    ], 'student', _now);
    expect(nextUnseenPinned(list, {})?.id, 'p2');
    expect(nextUnseenPinned(list, {'p2'})?.id, 'p1');
    expect(nextUnseenPinned(list, {'p1', 'p2'}), isNull);
  });

  test('a draft needs a title, a message and at least one group, within limits',
      () {
    AnnouncementDraftProblem? check(
            String title, String body, List<String> audience) =>
        announcementDraftProblem(title: title, body: body, audience: audience);
    expect(check(' ', 'm', ['teacher']), AnnouncementDraftProblem.titleMissing);
    expect(check('x' * 121, 'm', ['teacher']),
        AnnouncementDraftProblem.titleTooLong);
    expect(check('t', '  ', ['teacher']), AnnouncementDraftProblem.bodyMissing);
    expect(check('t', 'x' * 2001, ['teacher']),
        AnnouncementDraftProblem.bodyTooLong);
    expect(check('t', 'm', []), AnnouncementDraftProblem.noAudience);
    expect(check('t', 'm', ['circle_member']),
        AnnouncementDraftProblem.noAudience);
    expect(check('x' * 120, 'x' * 2000, ['parent']), isNull);
  });
}
