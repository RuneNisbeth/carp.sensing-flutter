/*
 * Copyright 2018 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

part of core;

/// Signature of a data transformer.
typedef DatumTransformer = Datum Function(Datum);

/// Signature of a data stream transformer.
typedef DatumStreamTransformer = Stream<Datum> Function(Stream<Datum>);

String _encode(Object object) => const JsonEncoder.withIndent(' ').convert(object);

/// Specify a schema for transforming data according to a set of privacy rules.
class PrivacySchema {
  Map<String, DatumTransformer> transformers = Map();

  PrivacySchema() : super();

  factory PrivacySchema.none() => PrivacySchema();
  factory PrivacySchema.full() => PrivacySchema();

  addProtector(String type, DatumTransformer protector) => transformers[type] = protector;

  /// Returns a privacy protected version of [data].
  ///
  /// If a transformer for this data type exists, the data is transformed.
  /// Otherwise, the same data is returned unchanged.
  Datum protect(Datum data) {
    Function transformer = transformers[data.format.name];
    return (transformer != null) ? transformer(data) : data;
  }
}

/// Specify how sampling should be done. Used to make default configuration of [Measure]s.
///
/// A new [SamplingSchema] can be created for specific purposes. For example, the following schema is
/// made for outdoor activity tracking.
///
///     SamplingSchema activitySchema = SamplingSchema(name: 'Outdoor Activity Sampling Schema', powerAware: true)
///       ..measures.addEntries([
///         MapEntry(DataType.PEDOMETER,
///           PeriodicMeasure(MeasureType(NameSpace.CARP, DataType.PEDOMETER), enabled: true, frequency: 60 * 60 * 1000)),
///         MapEntry(DataType.SCREEN, Measure(MeasureType(NameSpace.CARP, DataType.SCREEN), enabled: true)),
///         MapEntry(DataType.LOCATION, Measure(MeasureType(NameSpace.CARP, DataType.LOCATION), enabled: true)),
///         MapEntry(DataType.NOISE,
///           PeriodicMeasure(MeasureType(NameSpace.CARP, DataType.NOISE),
///             enabled: true, frequency: 60 * 1000, duration: 2 * 1000)),
///         MapEntry(DataType.ACTIVITY, Measure(MeasureType(NameSpace.CARP, DataType.ACTIVITY), enabled: true)),
///         MapEntry(DataType.WEATHER,
///           WeatherMeasure(MeasureType(NameSpace.CARP, DataType.WEATHER), enabled: true, frequency: 2 * 60 * 60 * 1000))
///       ]);
///
/// There is also a set of factory methods than provide different default sampling schemas, including:
///
/// * [`common`]() - a default, most common configuration of all known measures
/// * [`maximum`]() - using the `common` default configuration of all probes, but enabling all measures
/// * [`light`]() - a light configuration, enabling low-frequent sampling but with good coverage
/// * [`minimum`]() - a minimum set of measures, with a minimum sampling rate
/// * [`none`]() - no sampling at all (used to stop sampling)
///
/// See the [documentation](https://github.com/cph-cachet/carp.sensing-flutter/wiki/Schemas) for further details.
///
class SamplingSchema {
  /// The sampling schema type according to [SamplingSchemaType].
  String type;

  /// A printer-friendly name of this [SamplingSchema].
  String name;

  /// A map of default [Measure]s for this sampling schema.
  ///
  /// These default measures can be manually populated by
  /// adding [Measure]s to this map.
  Map<String, Measure> measures = Map<String, Measure>();

  /// Returns a list of [Measure]s from this [SamplingSchema] for
  /// a list of [MeasureType]s as specified in [types].
  ///
  /// This method is a convenient way to get a list of pre-configured
  /// measures of the correct type with default settings.
  /// For example using
  ///
  ///       SamplingSchema.common().getMeasureList(
  ///          [DataType.LOCATION, DataType.ACTIVITY, DataType.WEATHER]
  ///       );
  ///
  /// would return a list with a [Measure] for location and activity, a [WeatherMeasure] for weather,
  /// each with default configurations from the [SamplingSchema.common()] schema.
  ///
  /// If [namespace] is specified, then the returned measures' [MeasureType] belong to this namespace.
  /// Otherwise, the [NameSpace.UNKNOWN] is applied.
  List<Measure> getMeasureList(List<String> types, {String namespace}) {
    List<Measure> _list = List<Measure>();

    types.forEach((type) {
      if (measures.containsKey(type)) {
        // using json encoding/decoding to clone the measure object
        final _json = _encode(measures[type]);
        final Measure _clone = Measure.fromJson(json.decode(_json) as Map<String, dynamic>);
        _clone.type.namespace = namespace ?? NameSpace.UNKNOWN;
        _list.add(_clone);
      }
    });

    return _list;
  }

  /// Is this sampling schema power-aware, i.e. adapting its sampling strategy to
  /// the battery power status. See [PowerAwarenessState].
  bool powerAware = false;

  SamplingSchema({this.type, this.name, this.powerAware}) : super();

  /// A schema that does maximum sampling.
  ///
  /// Takes its settings from the [SamplingSchema.common()] schema, but enables all measures.
  factory SamplingSchema.maximum({String namespace}) => SamplingSchema.common(namespace: namespace)
    ..type = SamplingSchemaType.MAXIMUM
    ..name = 'Default ALL sampling'
    ..powerAware = true
    ..measures.values.forEach((measure) => measure.enabled = true);

  /// A default `common` sampling schema.
  ///
  /// This schema contains measure configurations based on best-effort experience
  /// and is intended for sampling on a daily basis with recharging
  /// at least once pr. day. This scheme is power-aware.
  ///
  /// These default settings are described in this [table](https://github.com/cph-cachet/carp.sensing-flutter/wiki/Schemas#samplingschemacommon).
  factory SamplingSchema.common({String namespace}) {
    namespace ??= NameSpace.UNKNOWN;
    return SamplingSchema()
      ..type = SamplingSchemaType.COMMON
      ..name = 'Common (default) sampling'
      ..powerAware = true
      ..measures.addEntries([
        MapEntry(DataType.DEVICE,
            Measure(MeasureType(namespace, DataType.DEVICE), name: 'Basic Device Info', enabled: true)),
        MapEntry(
            DataType.ACCELEROMETER,
            PeriodicMeasure(MeasureType(namespace, DataType.ACCELEROMETER),
                name: 'Accelerometer', enabled: false, frequency: 1000, duration: 10)),
        MapEntry(
            DataType.GYROSCOPE,
            PeriodicMeasure(MeasureType(namespace, DataType.GYROSCOPE),
                name: 'Gyroscope', enabled: false, frequency: 1000, duration: 10)),
        MapEntry(
            DataType.PEDOMETER,
            PeriodicMeasure(MeasureType(namespace, DataType.PEDOMETER),
                name: 'Pedometer (Step Count)', enabled: true, frequency: 60 * 60 * 1000)),
        MapEntry(
            DataType.LIGHT,
            PeriodicMeasure(MeasureType(namespace, DataType.LIGHT),
                name: 'Ambient Light', enabled: true, frequency: 60 * 1000, duration: 1000)),
        MapEntry(DataType.BATTERY, Measure(MeasureType(namespace, DataType.BATTERY), name: 'Battery', enabled: true)),
        MapEntry(DataType.SCREEN,
            Measure(MeasureType(namespace, DataType.SCREEN), name: 'Screen Activity (lock/on/off)', enabled: true)),
        MapEntry(
            DataType.MEMORY,
            PeriodicMeasure(MeasureType(namespace, DataType.MEMORY),
                name: 'Memory Usage', enabled: true, frequency: 60 * 1000)),
        MapEntry(
            DataType.LOCATION, Measure(MeasureType(namespace, DataType.LOCATION), name: 'Location', enabled: true)),
        MapEntry(DataType.CONNECTIVITY,
            Measure(MeasureType(namespace, DataType.CONNECTIVITY), name: 'Connectivity (wifi/3G/...)', enabled: true)),
        MapEntry(
            DataType.BLUETOOTH,
            PeriodicMeasure(MeasureType(namespace, DataType.BLUETOOTH),
                name: 'Nearby Devices (Bluetooth Scan)', enabled: true, frequency: 60 * 60 * 1000, duration: 2 * 1000)),
        MapEntry(
            DataType.APPS,
            PeriodicMeasure(MeasureType(namespace, DataType.APPS),
                name: 'Installed Apps', enabled: true, frequency: 24 * 60 * 60 * 1000)),
        MapEntry(
            DataType.APP_USAGE,
            PeriodicMeasure(MeasureType(namespace, DataType.APP_USAGE),
                name: 'Apps Usage', enabled: true, frequency: 60 * 60 * 1000, duration: 60 * 60 * 1000)),
        MapEntry(
            DataType.AUDIO,
            AudioMeasure(MeasureType(namespace, DataType.AUDIO),
                name: 'Audio Recording', enabled: false, frequency: 60 * 1000, duration: 2 * 1000)),
        MapEntry(
            DataType.NOISE,
            NoiseMeasure(MeasureType(namespace, DataType.NOISE),
                name: 'Ambient Noise', enabled: true, frequency: 60 * 1000, duration: 2 * 1000)),
        MapEntry(DataType.ACTIVITY,
            Measure(MeasureType(namespace, DataType.ACTIVITY), name: 'Activity Recognition', enabled: true)),
        MapEntry(DataType.PHONE_LOG,
            PhoneLogMeasure(MeasureType(namespace, DataType.PHONE_LOG), name: 'Phone Log', enabled: false, days: 30)),
        MapEntry(DataType.TEXT_MESSAGE_LOG,
            Measure(MeasureType(namespace, DataType.TEXT_MESSAGE_LOG), name: 'Text Message (SMS) Log', enabled: false)),
        MapEntry(DataType.TEXT_MESSAGE,
            Measure(MeasureType(namespace, DataType.TEXT_MESSAGE), name: 'Text Message (SMS)', enabled: true)),
        MapEntry(
            DataType.WEATHER,
            WeatherMeasure(MeasureType(namespace, DataType.WEATHER),
                name: 'Local Weather', enabled: true, frequency: 60 * 60 * 1000))
      ]);
  }

  /// A sampling schema that does not adapt any [Measure]s.
  ///
  /// This schema is used in the power-aware adaptation of sampling. See [PowerAwarenessState].
  /// [SamplingSchema.normal] is an empty schema and therefore don't change anything when
  /// used to adapt a [Study] and its [Measure]s in the [adapt] method.
  factory SamplingSchema.normal({String namespace, bool powerAware}) =>
      SamplingSchema(type: SamplingSchemaType.NORMAL, name: 'Default sampling', powerAware: powerAware);

  /// A default light sampling schema.
  ///
  /// This schema is used in the power-aware adaptation of sampling. See [PowerAwarenessState].
  /// This schema is intended for sampling on a daily basis with recharging
  /// at least once pr. day. This scheme is power-aware.
  ///
  /// See this [table](https://github.com/cph-cachet/carp.sensing-flutter/wiki/Schemas#samplingschemalight) for an overview.
  factory SamplingSchema.light({String namespace}) => SamplingSchema.common(namespace: namespace)
    ..type = SamplingSchemaType.LIGHT
    ..name = 'Light sampling'
    ..powerAware = true
    ..measures = (SamplingSchema.common(namespace: namespace).measures
      ..[DataType.LIGHT].enabled = false
      ..[DataType.MEMORY].enabled = false
      ..[DataType.CONNECTIVITY].enabled = false
      ..[DataType.BLUETOOTH].enabled = false
      ..[DataType.PHONE_LOG].enabled = false
      ..[DataType.TEXT_MESSAGE_LOG].enabled = false
      ..[DataType.TEXT_MESSAGE].enabled = false
      ..[DataType.WEATHER].enabled = false);

  /// A default minimum sampling schema.
  ///
  /// This schema is used in the power-aware adaptation of sampling. See [PowerAwarenessState].
  factory SamplingSchema.minimum({String namespace}) => SamplingSchema.light(namespace: namespace)
    ..type = SamplingSchemaType.MINIMUM
    ..name = 'Minimum sampling'
    ..powerAware = true
    ..measures = (SamplingSchema.light(namespace: namespace).measures
      ..[DataType.PEDOMETER].enabled = false
      ..[DataType.LOCATION].enabled = false
      ..[DataType.NOISE].enabled = false
      ..[DataType.ACTIVITY].enabled = false);

  /// A non-sampling sampling schema.
  ///
  /// This schema is used in the power-aware adaptation of sampling. See [PowerAwarenessState].
  /// This schema stops all sampling by disabling all probes.
  /// Sampling will be restored to the minimum level, once the device is
  /// recharged above the [PowerAwarenessState.MINIMUM_SAMPLING_LEVEL] level.
  factory SamplingSchema.none({String namespace}) {
    namespace ??= NameSpace.UNKNOWN;

    SamplingSchema schema = SamplingSchema(type: SamplingSchemaType.NONE, name: 'No sampling', powerAware: true);

    DataType.all.forEach((key) {
      schema.measures[key] = Measure(MeasureType(namespace, key), enabled: false);
    });

    return schema;
  }

  /// Adapts all [Measure]s in a [Study] to this [SamplingSchema].
  ///
  /// The following parameters are adapted
  ///   * [enabled] - a measure can be enabled / disabled based on this schema
  ///   * [frequency] - the sampling frequency can be adjusted based on this schema
  ///   * [duration] - the sampling duration can be adjusted based on this schema
  void adapt(Study study, {bool restore = true}) {
    study.tasks.forEach((task) {
      task.measures.forEach((measure) {
        // first restore each measure in the study+tasks to its previous value
        if (restore) measure.restore();
        if (measures.containsKey(measure.type.name)) {
          // if an adapted measure exists in this schema, adapt to this
          measure.adapt(measures[measure.type.name]);
        }
        // notify listeners that the measure has changed due to restoration and/or adaptation
        measure.hasChanged();
      });
    });
  }
}

/// A enumeration of known sampling schemas types.
class SamplingSchemaType {
  static const String MAXIMUM = "MAXIMUM";
  static const String COMMON = "COMMON";
  static const String NORMAL = "NORMAL";
  static const String LIGHT = "LIGHT";
  static const String MINIMUM = "MINIMUM";
  static const String NONE = "NONE";
}
