import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

DateTime startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime endOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}

Timestamp? rangeStartTimestamp(DateTimeRange? range) {
  if (range == null) return null;
  return Timestamp.fromDate(startOfDay(range.start));
}

Timestamp? rangeEndTimestamp(DateTimeRange? range) {
  if (range == null) return null;
  return Timestamp.fromDate(endOfDay(range.end));
}
