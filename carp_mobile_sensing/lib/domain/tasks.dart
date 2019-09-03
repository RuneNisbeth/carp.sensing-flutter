/*
 * Copyright 2018 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

part of domain;

/// A [Task] holds information about each task to be triggered by a [Trigger] as part of a [Study].
/// Each [Task] holds a list of [Measure]s to be done as part of this task.
/// A [Task] is hence merely an aggregation of [Measure]s.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class Task extends Serializable {
  static int _counter = 0;

  /// The name of this task. Unique for this [Study].
  String name;

  /// A list of [Measure]s to be done as part of this task.
  List<Measure> measures = new List<Measure>();

  Task([this.name]) : super() {
    name ??= 'Task #${_counter++}';
  }

  static Function get fromJsonFunction => _$TaskFromJson;
  factory Task.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory.fromJson(json[Serializable.CLASS_IDENTIFIER].toString(), json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);

  /// Add a [Measure] to this task.
  void addMeasure(Measure measure) {
    this.measures.add(measure);
  }

  /// Remove a [Measure] from this task.
  void removeMeasure(Measure measure) {
    this.measures.remove(measure);
  }

  String toString() => name;
}
