// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UndangUndangTableTable extends UndangUndangTable
    with TableInfo<$UndangUndangTableTable, UndangUndangTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UndangUndangTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kodeMeta = const VerificationMeta('kode');
  @override
  late final GeneratedColumn<String> kode = GeneratedColumn<String>(
    'kode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namaMeta = const VerificationMeta('nama');
  @override
  late final GeneratedColumn<String> nama = GeneratedColumn<String>(
    'nama',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namaLengkapMeta = const VerificationMeta(
    'namaLengkap',
  );
  @override
  late final GeneratedColumn<String> namaLengkap = GeneratedColumn<String>(
    'nama_lengkap',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deskripsiMeta = const VerificationMeta(
    'deskripsi',
  );
  @override
  late final GeneratedColumn<String> deskripsi = GeneratedColumn<String>(
    'deskripsi',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tahunMeta = const VerificationMeta('tahun');
  @override
  late final GeneratedColumn<int> tahun = GeneratedColumn<int>(
    'tahun',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _officialUrlMeta = const VerificationMeta(
    'officialUrl',
  );
  @override
  late final GeneratedColumn<String> officialUrl = GeneratedColumn<String>(
    'official_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kode,
    nama,
    namaLengkap,
    deskripsi,
    tahun,
    isActive,
    updatedAt,
    officialUrl,
    sourceUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'undang_undang_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<UndangUndangTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kode')) {
      context.handle(
        _kodeMeta,
        kode.isAcceptableOrUnknown(data['kode']!, _kodeMeta),
      );
    } else if (isInserting) {
      context.missing(_kodeMeta);
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('nama_lengkap')) {
      context.handle(
        _namaLengkapMeta,
        namaLengkap.isAcceptableOrUnknown(
          data['nama_lengkap']!,
          _namaLengkapMeta,
        ),
      );
    }
    if (data.containsKey('deskripsi')) {
      context.handle(
        _deskripsiMeta,
        deskripsi.isAcceptableOrUnknown(data['deskripsi']!, _deskripsiMeta),
      );
    }
    if (data.containsKey('tahun')) {
      context.handle(
        _tahunMeta,
        tahun.isAcceptableOrUnknown(data['tahun']!, _tahunMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('official_url')) {
      context.handle(
        _officialUrlMeta,
        officialUrl.isAcceptableOrUnknown(
          data['official_url']!,
          _officialUrlMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UndangUndangTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UndangUndangTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kode'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      namaLengkap: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama_lengkap'],
      ),
      deskripsi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deskripsi'],
      ),
      tahun: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tahun'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      officialUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}official_url'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
    );
  }

  @override
  $UndangUndangTableTable createAlias(String alias) {
    return $UndangUndangTableTable(attachedDatabase, alias);
  }
}

class UndangUndangTableData extends DataClass
    implements Insertable<UndangUndangTableData> {
  final String id;
  final String kode;
  final String nama;
  final String? namaLengkap;
  final String? deskripsi;
  final int tahun;
  final bool isActive;
  final DateTime? updatedAt;
  final String? officialUrl;
  final String? sourceUrl;
  const UndangUndangTableData({
    required this.id,
    required this.kode,
    required this.nama,
    this.namaLengkap,
    this.deskripsi,
    required this.tahun,
    required this.isActive,
    this.updatedAt,
    this.officialUrl,
    this.sourceUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kode'] = Variable<String>(kode);
    map['nama'] = Variable<String>(nama);
    if (!nullToAbsent || namaLengkap != null) {
      map['nama_lengkap'] = Variable<String>(namaLengkap);
    }
    if (!nullToAbsent || deskripsi != null) {
      map['deskripsi'] = Variable<String>(deskripsi);
    }
    map['tahun'] = Variable<int>(tahun);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || officialUrl != null) {
      map['official_url'] = Variable<String>(officialUrl);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    return map;
  }

  UndangUndangTableCompanion toCompanion(bool nullToAbsent) {
    return UndangUndangTableCompanion(
      id: Value(id),
      kode: Value(kode),
      nama: Value(nama),
      namaLengkap: namaLengkap == null && nullToAbsent
          ? const Value.absent()
          : Value(namaLengkap),
      deskripsi: deskripsi == null && nullToAbsent
          ? const Value.absent()
          : Value(deskripsi),
      tahun: Value(tahun),
      isActive: Value(isActive),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      officialUrl: officialUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(officialUrl),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
    );
  }

  factory UndangUndangTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UndangUndangTableData(
      id: serializer.fromJson<String>(json['id']),
      kode: serializer.fromJson<String>(json['kode']),
      nama: serializer.fromJson<String>(json['nama']),
      namaLengkap: serializer.fromJson<String?>(json['namaLengkap']),
      deskripsi: serializer.fromJson<String?>(json['deskripsi']),
      tahun: serializer.fromJson<int>(json['tahun']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      officialUrl: serializer.fromJson<String?>(json['officialUrl']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kode': serializer.toJson<String>(kode),
      'nama': serializer.toJson<String>(nama),
      'namaLengkap': serializer.toJson<String?>(namaLengkap),
      'deskripsi': serializer.toJson<String?>(deskripsi),
      'tahun': serializer.toJson<int>(tahun),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'officialUrl': serializer.toJson<String?>(officialUrl),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
    };
  }

  UndangUndangTableData copyWith({
    String? id,
    String? kode,
    String? nama,
    Value<String?> namaLengkap = const Value.absent(),
    Value<String?> deskripsi = const Value.absent(),
    int? tahun,
    bool? isActive,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<String?> officialUrl = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
  }) => UndangUndangTableData(
    id: id ?? this.id,
    kode: kode ?? this.kode,
    nama: nama ?? this.nama,
    namaLengkap: namaLengkap.present ? namaLengkap.value : this.namaLengkap,
    deskripsi: deskripsi.present ? deskripsi.value : this.deskripsi,
    tahun: tahun ?? this.tahun,
    isActive: isActive ?? this.isActive,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    officialUrl: officialUrl.present ? officialUrl.value : this.officialUrl,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
  );
  UndangUndangTableData copyWithCompanion(UndangUndangTableCompanion data) {
    return UndangUndangTableData(
      id: data.id.present ? data.id.value : this.id,
      kode: data.kode.present ? data.kode.value : this.kode,
      nama: data.nama.present ? data.nama.value : this.nama,
      namaLengkap: data.namaLengkap.present
          ? data.namaLengkap.value
          : this.namaLengkap,
      deskripsi: data.deskripsi.present ? data.deskripsi.value : this.deskripsi,
      tahun: data.tahun.present ? data.tahun.value : this.tahun,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      officialUrl: data.officialUrl.present
          ? data.officialUrl.value
          : this.officialUrl,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UndangUndangTableData(')
          ..write('id: $id, ')
          ..write('kode: $kode, ')
          ..write('nama: $nama, ')
          ..write('namaLengkap: $namaLengkap, ')
          ..write('deskripsi: $deskripsi, ')
          ..write('tahun: $tahun, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('officialUrl: $officialUrl, ')
          ..write('sourceUrl: $sourceUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kode,
    nama,
    namaLengkap,
    deskripsi,
    tahun,
    isActive,
    updatedAt,
    officialUrl,
    sourceUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UndangUndangTableData &&
          other.id == this.id &&
          other.kode == this.kode &&
          other.nama == this.nama &&
          other.namaLengkap == this.namaLengkap &&
          other.deskripsi == this.deskripsi &&
          other.tahun == this.tahun &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt &&
          other.officialUrl == this.officialUrl &&
          other.sourceUrl == this.sourceUrl);
}

class UndangUndangTableCompanion
    extends UpdateCompanion<UndangUndangTableData> {
  final Value<String> id;
  final Value<String> kode;
  final Value<String> nama;
  final Value<String?> namaLengkap;
  final Value<String?> deskripsi;
  final Value<int> tahun;
  final Value<bool> isActive;
  final Value<DateTime?> updatedAt;
  final Value<String?> officialUrl;
  final Value<String?> sourceUrl;
  final Value<int> rowid;
  const UndangUndangTableCompanion({
    this.id = const Value.absent(),
    this.kode = const Value.absent(),
    this.nama = const Value.absent(),
    this.namaLengkap = const Value.absent(),
    this.deskripsi = const Value.absent(),
    this.tahun = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.officialUrl = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UndangUndangTableCompanion.insert({
    required String id,
    required String kode,
    required String nama,
    this.namaLengkap = const Value.absent(),
    this.deskripsi = const Value.absent(),
    this.tahun = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.officialUrl = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kode = Value(kode),
       nama = Value(nama);
  static Insertable<UndangUndangTableData> custom({
    Expression<String>? id,
    Expression<String>? kode,
    Expression<String>? nama,
    Expression<String>? namaLengkap,
    Expression<String>? deskripsi,
    Expression<int>? tahun,
    Expression<bool>? isActive,
    Expression<DateTime>? updatedAt,
    Expression<String>? officialUrl,
    Expression<String>? sourceUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kode != null) 'kode': kode,
      if (nama != null) 'nama': nama,
      if (namaLengkap != null) 'nama_lengkap': namaLengkap,
      if (deskripsi != null) 'deskripsi': deskripsi,
      if (tahun != null) 'tahun': tahun,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (officialUrl != null) 'official_url': officialUrl,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UndangUndangTableCompanion copyWith({
    Value<String>? id,
    Value<String>? kode,
    Value<String>? nama,
    Value<String?>? namaLengkap,
    Value<String?>? deskripsi,
    Value<int>? tahun,
    Value<bool>? isActive,
    Value<DateTime?>? updatedAt,
    Value<String?>? officialUrl,
    Value<String?>? sourceUrl,
    Value<int>? rowid,
  }) {
    return UndangUndangTableCompanion(
      id: id ?? this.id,
      kode: kode ?? this.kode,
      nama: nama ?? this.nama,
      namaLengkap: namaLengkap ?? this.namaLengkap,
      deskripsi: deskripsi ?? this.deskripsi,
      tahun: tahun ?? this.tahun,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      officialUrl: officialUrl ?? this.officialUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kode.present) {
      map['kode'] = Variable<String>(kode.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (namaLengkap.present) {
      map['nama_lengkap'] = Variable<String>(namaLengkap.value);
    }
    if (deskripsi.present) {
      map['deskripsi'] = Variable<String>(deskripsi.value);
    }
    if (tahun.present) {
      map['tahun'] = Variable<int>(tahun.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (officialUrl.present) {
      map['official_url'] = Variable<String>(officialUrl.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UndangUndangTableCompanion(')
          ..write('id: $id, ')
          ..write('kode: $kode, ')
          ..write('nama: $nama, ')
          ..write('namaLengkap: $namaLengkap, ')
          ..write('deskripsi: $deskripsi, ')
          ..write('tahun: $tahun, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('officialUrl: $officialUrl, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PasalTableTable extends PasalTable
    with TableInfo<$PasalTableTable, PasalTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PasalTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _undangUndangIdMeta = const VerificationMeta(
    'undangUndangId',
  );
  @override
  late final GeneratedColumn<String> undangUndangId = GeneratedColumn<String>(
    'undang_undang_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nomorMeta = const VerificationMeta('nomor');
  @override
  late final GeneratedColumn<String> nomor = GeneratedColumn<String>(
    'nomor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isiMeta = const VerificationMeta('isi');
  @override
  late final GeneratedColumn<String> isi = GeneratedColumn<String>(
    'isi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _penjelasanMeta = const VerificationMeta(
    'penjelasan',
  );
  @override
  late final GeneratedColumn<String> penjelasan = GeneratedColumn<String>(
    'penjelasan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _judulMeta = const VerificationMeta('judul');
  @override
  late final GeneratedColumn<String> judul = GeneratedColumn<String>(
    'judul',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _babMeta = const VerificationMeta('bab');
  @override
  late final GeneratedColumn<String> bab = GeneratedColumn<String>(
    'bab',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relatedIdsMeta = const VerificationMeta(
    'relatedIds',
  );
  @override
  late final GeneratedColumn<String> relatedIds = GeneratedColumn<String>(
    'related_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verificationStatusMeta =
      const VerificationMeta('verificationStatus');
  @override
  late final GeneratedColumn<String> verificationStatus =
      GeneratedColumn<String>(
        'verification_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('perlu_verifikasi'),
      );
  static const VerificationMeta _verifiedAtMeta = const VerificationMeta(
    'verifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> verifiedAt = GeneratedColumn<DateTime>(
    'verified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    undangUndangId,
    nomor,
    isi,
    penjelasan,
    judul,
    bab,
    relatedIds,
    isActive,
    createdAt,
    updatedAt,
    verificationStatus,
    verifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pasal_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PasalTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('undang_undang_id')) {
      context.handle(
        _undangUndangIdMeta,
        undangUndangId.isAcceptableOrUnknown(
          data['undang_undang_id']!,
          _undangUndangIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_undangUndangIdMeta);
    }
    if (data.containsKey('nomor')) {
      context.handle(
        _nomorMeta,
        nomor.isAcceptableOrUnknown(data['nomor']!, _nomorMeta),
      );
    } else if (isInserting) {
      context.missing(_nomorMeta);
    }
    if (data.containsKey('isi')) {
      context.handle(
        _isiMeta,
        isi.isAcceptableOrUnknown(data['isi']!, _isiMeta),
      );
    } else if (isInserting) {
      context.missing(_isiMeta);
    }
    if (data.containsKey('penjelasan')) {
      context.handle(
        _penjelasanMeta,
        penjelasan.isAcceptableOrUnknown(data['penjelasan']!, _penjelasanMeta),
      );
    }
    if (data.containsKey('judul')) {
      context.handle(
        _judulMeta,
        judul.isAcceptableOrUnknown(data['judul']!, _judulMeta),
      );
    }
    if (data.containsKey('bab')) {
      context.handle(
        _babMeta,
        bab.isAcceptableOrUnknown(data['bab']!, _babMeta),
      );
    }
    if (data.containsKey('related_ids')) {
      context.handle(
        _relatedIdsMeta,
        relatedIds.isAcceptableOrUnknown(data['related_ids']!, _relatedIdsMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('verification_status')) {
      context.handle(
        _verificationStatusMeta,
        verificationStatus.isAcceptableOrUnknown(
          data['verification_status']!,
          _verificationStatusMeta,
        ),
      );
    }
    if (data.containsKey('verified_at')) {
      context.handle(
        _verifiedAtMeta,
        verifiedAt.isAcceptableOrUnknown(data['verified_at']!, _verifiedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {undangUndangId, nomor},
  ];
  @override
  PasalTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PasalTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      undangUndangId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}undang_undang_id'],
      )!,
      nomor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nomor'],
      )!,
      isi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isi'],
      )!,
      penjelasan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}penjelasan'],
      ),
      judul: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}judul'],
      ),
      bab: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bab'],
      ),
      relatedIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_ids'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      verificationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification_status'],
      )!,
      verifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}verified_at'],
      ),
    );
  }

  @override
  $PasalTableTable createAlias(String alias) {
    return $PasalTableTable(attachedDatabase, alias);
  }
}

class PasalTableData extends DataClass implements Insertable<PasalTableData> {
  final String id;
  final String undangUndangId;
  final String nomor;
  final String isi;
  final String? penjelasan;
  final String? judul;
  final String? bab;
  final String relatedIds;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String verificationStatus;
  final DateTime? verifiedAt;
  const PasalTableData({
    required this.id,
    required this.undangUndangId,
    required this.nomor,
    required this.isi,
    this.penjelasan,
    this.judul,
    this.bab,
    required this.relatedIds,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    required this.verificationStatus,
    this.verifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['undang_undang_id'] = Variable<String>(undangUndangId);
    map['nomor'] = Variable<String>(nomor);
    map['isi'] = Variable<String>(isi);
    if (!nullToAbsent || penjelasan != null) {
      map['penjelasan'] = Variable<String>(penjelasan);
    }
    if (!nullToAbsent || judul != null) {
      map['judul'] = Variable<String>(judul);
    }
    if (!nullToAbsent || bab != null) {
      map['bab'] = Variable<String>(bab);
    }
    map['related_ids'] = Variable<String>(relatedIds);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['verification_status'] = Variable<String>(verificationStatus);
    if (!nullToAbsent || verifiedAt != null) {
      map['verified_at'] = Variable<DateTime>(verifiedAt);
    }
    return map;
  }

  PasalTableCompanion toCompanion(bool nullToAbsent) {
    return PasalTableCompanion(
      id: Value(id),
      undangUndangId: Value(undangUndangId),
      nomor: Value(nomor),
      isi: Value(isi),
      penjelasan: penjelasan == null && nullToAbsent
          ? const Value.absent()
          : Value(penjelasan),
      judul: judul == null && nullToAbsent
          ? const Value.absent()
          : Value(judul),
      bab: bab == null && nullToAbsent ? const Value.absent() : Value(bab),
      relatedIds: Value(relatedIds),
      isActive: Value(isActive),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      verificationStatus: Value(verificationStatus),
      verifiedAt: verifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(verifiedAt),
    );
  }

  factory PasalTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PasalTableData(
      id: serializer.fromJson<String>(json['id']),
      undangUndangId: serializer.fromJson<String>(json['undangUndangId']),
      nomor: serializer.fromJson<String>(json['nomor']),
      isi: serializer.fromJson<String>(json['isi']),
      penjelasan: serializer.fromJson<String?>(json['penjelasan']),
      judul: serializer.fromJson<String?>(json['judul']),
      bab: serializer.fromJson<String?>(json['bab']),
      relatedIds: serializer.fromJson<String>(json['relatedIds']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      verificationStatus: serializer.fromJson<String>(
        json['verificationStatus'],
      ),
      verifiedAt: serializer.fromJson<DateTime?>(json['verifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'undangUndangId': serializer.toJson<String>(undangUndangId),
      'nomor': serializer.toJson<String>(nomor),
      'isi': serializer.toJson<String>(isi),
      'penjelasan': serializer.toJson<String?>(penjelasan),
      'judul': serializer.toJson<String?>(judul),
      'bab': serializer.toJson<String?>(bab),
      'relatedIds': serializer.toJson<String>(relatedIds),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'verificationStatus': serializer.toJson<String>(verificationStatus),
      'verifiedAt': serializer.toJson<DateTime?>(verifiedAt),
    };
  }

  PasalTableData copyWith({
    String? id,
    String? undangUndangId,
    String? nomor,
    String? isi,
    Value<String?> penjelasan = const Value.absent(),
    Value<String?> judul = const Value.absent(),
    Value<String?> bab = const Value.absent(),
    String? relatedIds,
    bool? isActive,
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    String? verificationStatus,
    Value<DateTime?> verifiedAt = const Value.absent(),
  }) => PasalTableData(
    id: id ?? this.id,
    undangUndangId: undangUndangId ?? this.undangUndangId,
    nomor: nomor ?? this.nomor,
    isi: isi ?? this.isi,
    penjelasan: penjelasan.present ? penjelasan.value : this.penjelasan,
    judul: judul.present ? judul.value : this.judul,
    bab: bab.present ? bab.value : this.bab,
    relatedIds: relatedIds ?? this.relatedIds,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    verifiedAt: verifiedAt.present ? verifiedAt.value : this.verifiedAt,
  );
  PasalTableData copyWithCompanion(PasalTableCompanion data) {
    return PasalTableData(
      id: data.id.present ? data.id.value : this.id,
      undangUndangId: data.undangUndangId.present
          ? data.undangUndangId.value
          : this.undangUndangId,
      nomor: data.nomor.present ? data.nomor.value : this.nomor,
      isi: data.isi.present ? data.isi.value : this.isi,
      penjelasan: data.penjelasan.present
          ? data.penjelasan.value
          : this.penjelasan,
      judul: data.judul.present ? data.judul.value : this.judul,
      bab: data.bab.present ? data.bab.value : this.bab,
      relatedIds: data.relatedIds.present
          ? data.relatedIds.value
          : this.relatedIds,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      verificationStatus: data.verificationStatus.present
          ? data.verificationStatus.value
          : this.verificationStatus,
      verifiedAt: data.verifiedAt.present
          ? data.verifiedAt.value
          : this.verifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PasalTableData(')
          ..write('id: $id, ')
          ..write('undangUndangId: $undangUndangId, ')
          ..write('nomor: $nomor, ')
          ..write('isi: $isi, ')
          ..write('penjelasan: $penjelasan, ')
          ..write('judul: $judul, ')
          ..write('bab: $bab, ')
          ..write('relatedIds: $relatedIds, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('verificationStatus: $verificationStatus, ')
          ..write('verifiedAt: $verifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    undangUndangId,
    nomor,
    isi,
    penjelasan,
    judul,
    bab,
    relatedIds,
    isActive,
    createdAt,
    updatedAt,
    verificationStatus,
    verifiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PasalTableData &&
          other.id == this.id &&
          other.undangUndangId == this.undangUndangId &&
          other.nomor == this.nomor &&
          other.isi == this.isi &&
          other.penjelasan == this.penjelasan &&
          other.judul == this.judul &&
          other.bab == this.bab &&
          other.relatedIds == this.relatedIds &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.verificationStatus == this.verificationStatus &&
          other.verifiedAt == this.verifiedAt);
}

class PasalTableCompanion extends UpdateCompanion<PasalTableData> {
  final Value<String> id;
  final Value<String> undangUndangId;
  final Value<String> nomor;
  final Value<String> isi;
  final Value<String?> penjelasan;
  final Value<String?> judul;
  final Value<String?> bab;
  final Value<String> relatedIds;
  final Value<bool> isActive;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<String> verificationStatus;
  final Value<DateTime?> verifiedAt;
  final Value<int> rowid;
  const PasalTableCompanion({
    this.id = const Value.absent(),
    this.undangUndangId = const Value.absent(),
    this.nomor = const Value.absent(),
    this.isi = const Value.absent(),
    this.penjelasan = const Value.absent(),
    this.judul = const Value.absent(),
    this.bab = const Value.absent(),
    this.relatedIds = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.verificationStatus = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PasalTableCompanion.insert({
    required String id,
    required String undangUndangId,
    required String nomor,
    required String isi,
    this.penjelasan = const Value.absent(),
    this.judul = const Value.absent(),
    this.bab = const Value.absent(),
    this.relatedIds = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.verificationStatus = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       undangUndangId = Value(undangUndangId),
       nomor = Value(nomor),
       isi = Value(isi);
  static Insertable<PasalTableData> custom({
    Expression<String>? id,
    Expression<String>? undangUndangId,
    Expression<String>? nomor,
    Expression<String>? isi,
    Expression<String>? penjelasan,
    Expression<String>? judul,
    Expression<String>? bab,
    Expression<String>? relatedIds,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? verificationStatus,
    Expression<DateTime>? verifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (undangUndangId != null) 'undang_undang_id': undangUndangId,
      if (nomor != null) 'nomor': nomor,
      if (isi != null) 'isi': isi,
      if (penjelasan != null) 'penjelasan': penjelasan,
      if (judul != null) 'judul': judul,
      if (bab != null) 'bab': bab,
      if (relatedIds != null) 'related_ids': relatedIds,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (verificationStatus != null) 'verification_status': verificationStatus,
      if (verifiedAt != null) 'verified_at': verifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PasalTableCompanion copyWith({
    Value<String>? id,
    Value<String>? undangUndangId,
    Value<String>? nomor,
    Value<String>? isi,
    Value<String?>? penjelasan,
    Value<String?>? judul,
    Value<String?>? bab,
    Value<String>? relatedIds,
    Value<bool>? isActive,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<String>? verificationStatus,
    Value<DateTime?>? verifiedAt,
    Value<int>? rowid,
  }) {
    return PasalTableCompanion(
      id: id ?? this.id,
      undangUndangId: undangUndangId ?? this.undangUndangId,
      nomor: nomor ?? this.nomor,
      isi: isi ?? this.isi,
      penjelasan: penjelasan ?? this.penjelasan,
      judul: judul ?? this.judul,
      bab: bab ?? this.bab,
      relatedIds: relatedIds ?? this.relatedIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (undangUndangId.present) {
      map['undang_undang_id'] = Variable<String>(undangUndangId.value);
    }
    if (nomor.present) {
      map['nomor'] = Variable<String>(nomor.value);
    }
    if (isi.present) {
      map['isi'] = Variable<String>(isi.value);
    }
    if (penjelasan.present) {
      map['penjelasan'] = Variable<String>(penjelasan.value);
    }
    if (judul.present) {
      map['judul'] = Variable<String>(judul.value);
    }
    if (bab.present) {
      map['bab'] = Variable<String>(bab.value);
    }
    if (relatedIds.present) {
      map['related_ids'] = Variable<String>(relatedIds.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (verificationStatus.present) {
      map['verification_status'] = Variable<String>(verificationStatus.value);
    }
    if (verifiedAt.present) {
      map['verified_at'] = Variable<DateTime>(verifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PasalTableCompanion(')
          ..write('id: $id, ')
          ..write('undangUndangId: $undangUndangId, ')
          ..write('nomor: $nomor, ')
          ..write('isi: $isi, ')
          ..write('penjelasan: $penjelasan, ')
          ..write('judul: $judul, ')
          ..write('bab: $bab, ')
          ..write('relatedIds: $relatedIds, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('verificationStatus: $verificationStatus, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PasalLinksTableTable extends PasalLinksTable
    with TableInfo<$PasalLinksTableTable, PasalLinksTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PasalLinksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePasalIdMeta = const VerificationMeta(
    'sourcePasalId',
  );
  @override
  late final GeneratedColumn<String> sourcePasalId = GeneratedColumn<String>(
    'source_pasal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetPasalIdMeta = const VerificationMeta(
    'targetPasalId',
  );
  @override
  late final GeneratedColumn<String> targetPasalId = GeneratedColumn<String>(
    'target_pasal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keteranganMeta = const VerificationMeta(
    'keterangan',
  );
  @override
  late final GeneratedColumn<String> keterangan = GeneratedColumn<String>(
    'keterangan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourcePasalId,
    targetPasalId,
    keterangan,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pasal_links_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PasalLinksTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_pasal_id')) {
      context.handle(
        _sourcePasalIdMeta,
        sourcePasalId.isAcceptableOrUnknown(
          data['source_pasal_id']!,
          _sourcePasalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcePasalIdMeta);
    }
    if (data.containsKey('target_pasal_id')) {
      context.handle(
        _targetPasalIdMeta,
        targetPasalId.isAcceptableOrUnknown(
          data['target_pasal_id']!,
          _targetPasalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetPasalIdMeta);
    }
    if (data.containsKey('keterangan')) {
      context.handle(
        _keteranganMeta,
        keterangan.isAcceptableOrUnknown(data['keterangan']!, _keteranganMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourcePasalId, targetPasalId},
  ];
  @override
  PasalLinksTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PasalLinksTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourcePasalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_pasal_id'],
      )!,
      targetPasalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_pasal_id'],
      )!,
      keterangan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keterangan'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $PasalLinksTableTable createAlias(String alias) {
    return $PasalLinksTableTable(attachedDatabase, alias);
  }
}

class PasalLinksTableData extends DataClass
    implements Insertable<PasalLinksTableData> {
  final String id;
  final String sourcePasalId;
  final String targetPasalId;
  final String? keterangan;
  final bool isActive;
  final DateTime? createdAt;
  const PasalLinksTableData({
    required this.id,
    required this.sourcePasalId,
    required this.targetPasalId,
    this.keterangan,
    required this.isActive,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_pasal_id'] = Variable<String>(sourcePasalId);
    map['target_pasal_id'] = Variable<String>(targetPasalId);
    if (!nullToAbsent || keterangan != null) {
      map['keterangan'] = Variable<String>(keterangan);
    }
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  PasalLinksTableCompanion toCompanion(bool nullToAbsent) {
    return PasalLinksTableCompanion(
      id: Value(id),
      sourcePasalId: Value(sourcePasalId),
      targetPasalId: Value(targetPasalId),
      keterangan: keterangan == null && nullToAbsent
          ? const Value.absent()
          : Value(keterangan),
      isActive: Value(isActive),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory PasalLinksTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PasalLinksTableData(
      id: serializer.fromJson<String>(json['id']),
      sourcePasalId: serializer.fromJson<String>(json['sourcePasalId']),
      targetPasalId: serializer.fromJson<String>(json['targetPasalId']),
      keterangan: serializer.fromJson<String?>(json['keterangan']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourcePasalId': serializer.toJson<String>(sourcePasalId),
      'targetPasalId': serializer.toJson<String>(targetPasalId),
      'keterangan': serializer.toJson<String?>(keterangan),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  PasalLinksTableData copyWith({
    String? id,
    String? sourcePasalId,
    String? targetPasalId,
    Value<String?> keterangan = const Value.absent(),
    bool? isActive,
    Value<DateTime?> createdAt = const Value.absent(),
  }) => PasalLinksTableData(
    id: id ?? this.id,
    sourcePasalId: sourcePasalId ?? this.sourcePasalId,
    targetPasalId: targetPasalId ?? this.targetPasalId,
    keterangan: keterangan.present ? keterangan.value : this.keterangan,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  PasalLinksTableData copyWithCompanion(PasalLinksTableCompanion data) {
    return PasalLinksTableData(
      id: data.id.present ? data.id.value : this.id,
      sourcePasalId: data.sourcePasalId.present
          ? data.sourcePasalId.value
          : this.sourcePasalId,
      targetPasalId: data.targetPasalId.present
          ? data.targetPasalId.value
          : this.targetPasalId,
      keterangan: data.keterangan.present
          ? data.keterangan.value
          : this.keterangan,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PasalLinksTableData(')
          ..write('id: $id, ')
          ..write('sourcePasalId: $sourcePasalId, ')
          ..write('targetPasalId: $targetPasalId, ')
          ..write('keterangan: $keterangan, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourcePasalId,
    targetPasalId,
    keterangan,
    isActive,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PasalLinksTableData &&
          other.id == this.id &&
          other.sourcePasalId == this.sourcePasalId &&
          other.targetPasalId == this.targetPasalId &&
          other.keterangan == this.keterangan &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class PasalLinksTableCompanion extends UpdateCompanion<PasalLinksTableData> {
  final Value<String> id;
  final Value<String> sourcePasalId;
  final Value<String> targetPasalId;
  final Value<String?> keterangan;
  final Value<bool> isActive;
  final Value<DateTime?> createdAt;
  final Value<int> rowid;
  const PasalLinksTableCompanion({
    this.id = const Value.absent(),
    this.sourcePasalId = const Value.absent(),
    this.targetPasalId = const Value.absent(),
    this.keterangan = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PasalLinksTableCompanion.insert({
    required String id,
    required String sourcePasalId,
    required String targetPasalId,
    this.keterangan = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourcePasalId = Value(sourcePasalId),
       targetPasalId = Value(targetPasalId);
  static Insertable<PasalLinksTableData> custom({
    Expression<String>? id,
    Expression<String>? sourcePasalId,
    Expression<String>? targetPasalId,
    Expression<String>? keterangan,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourcePasalId != null) 'source_pasal_id': sourcePasalId,
      if (targetPasalId != null) 'target_pasal_id': targetPasalId,
      if (keterangan != null) 'keterangan': keterangan,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PasalLinksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? sourcePasalId,
    Value<String>? targetPasalId,
    Value<String?>? keterangan,
    Value<bool>? isActive,
    Value<DateTime?>? createdAt,
    Value<int>? rowid,
  }) {
    return PasalLinksTableCompanion(
      id: id ?? this.id,
      sourcePasalId: sourcePasalId ?? this.sourcePasalId,
      targetPasalId: targetPasalId ?? this.targetPasalId,
      keterangan: keterangan ?? this.keterangan,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourcePasalId.present) {
      map['source_pasal_id'] = Variable<String>(sourcePasalId.value);
    }
    if (targetPasalId.present) {
      map['target_pasal_id'] = Variable<String>(targetPasalId.value);
    }
    if (keterangan.present) {
      map['keterangan'] = Variable<String>(keterangan.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PasalLinksTableCompanion(')
          ..write('id: $id, ')
          ..write('sourcePasalId: $sourcePasalId, ')
          ..write('targetPasalId: $targetPasalId, ')
          ..write('keterangan: $keterangan, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PasalVersiTableTable extends PasalVersiTable
    with TableInfo<$PasalVersiTableTable, PasalVersiTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PasalVersiTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pasalIdMeta = const VerificationMeta(
    'pasalId',
  );
  @override
  late final GeneratedColumn<String> pasalId = GeneratedColumn<String>(
    'pasal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urutanMeta = const VerificationMeta('urutan');
  @override
  late final GeneratedColumn<int> urutan = GeneratedColumn<int>(
    'urutan',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sumberMeta = const VerificationMeta('sumber');
  @override
  late final GeneratedColumn<String> sumber = GeneratedColumn<String>(
    'sumber',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _judulSumberMeta = const VerificationMeta(
    'judulSumber',
  );
  @override
  late final GeneratedColumn<String> judulSumber = GeneratedColumn<String>(
    'judul_sumber',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diundangkanMeta = const VerificationMeta(
    'diundangkan',
  );
  @override
  late final GeneratedColumn<String> diundangkan = GeneratedColumn<String>(
    'diundangkan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _berlakuSejakMeta = const VerificationMeta(
    'berlakuSejak',
  );
  @override
  late final GeneratedColumn<String> berlakuSejak = GeneratedColumn<String>(
    'berlaku_sejak',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _naskahResmiMeta = const VerificationMeta(
    'naskahResmi',
  );
  @override
  late final GeneratedColumn<String> naskahResmi = GeneratedColumn<String>(
    'naskah_resmi',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isiMeta = const VerificationMeta('isi');
  @override
  late final GeneratedColumn<String> isi = GeneratedColumn<String>(
    'isi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _penjelasanMeta = const VerificationMeta(
    'penjelasan',
  );
  @override
  late final GeneratedColumn<String> penjelasan = GeneratedColumn<String>(
    'penjelasan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pasalId,
    urutan,
    status,
    sumber,
    judulSumber,
    diundangkan,
    berlakuSejak,
    naskahResmi,
    isi,
    penjelasan,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pasal_versi_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PasalVersiTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pasal_id')) {
      context.handle(
        _pasalIdMeta,
        pasalId.isAcceptableOrUnknown(data['pasal_id']!, _pasalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pasalIdMeta);
    }
    if (data.containsKey('urutan')) {
      context.handle(
        _urutanMeta,
        urutan.isAcceptableOrUnknown(data['urutan']!, _urutanMeta),
      );
    } else if (isInserting) {
      context.missing(_urutanMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('sumber')) {
      context.handle(
        _sumberMeta,
        sumber.isAcceptableOrUnknown(data['sumber']!, _sumberMeta),
      );
    }
    if (data.containsKey('judul_sumber')) {
      context.handle(
        _judulSumberMeta,
        judulSumber.isAcceptableOrUnknown(
          data['judul_sumber']!,
          _judulSumberMeta,
        ),
      );
    }
    if (data.containsKey('diundangkan')) {
      context.handle(
        _diundangkanMeta,
        diundangkan.isAcceptableOrUnknown(
          data['diundangkan']!,
          _diundangkanMeta,
        ),
      );
    }
    if (data.containsKey('berlaku_sejak')) {
      context.handle(
        _berlakuSejakMeta,
        berlakuSejak.isAcceptableOrUnknown(
          data['berlaku_sejak']!,
          _berlakuSejakMeta,
        ),
      );
    }
    if (data.containsKey('naskah_resmi')) {
      context.handle(
        _naskahResmiMeta,
        naskahResmi.isAcceptableOrUnknown(
          data['naskah_resmi']!,
          _naskahResmiMeta,
        ),
      );
    }
    if (data.containsKey('isi')) {
      context.handle(
        _isiMeta,
        isi.isAcceptableOrUnknown(data['isi']!, _isiMeta),
      );
    } else if (isInserting) {
      context.missing(_isiMeta);
    }
    if (data.containsKey('penjelasan')) {
      context.handle(
        _penjelasanMeta,
        penjelasan.isAcceptableOrUnknown(data['penjelasan']!, _penjelasanMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PasalVersiTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PasalVersiTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pasalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pasal_id'],
      )!,
      urutan: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}urutan'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sumber'],
      ),
      judulSumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}judul_sumber'],
      ),
      diundangkan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diundangkan'],
      ),
      berlakuSejak: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}berlaku_sejak'],
      ),
      naskahResmi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}naskah_resmi'],
      ),
      isi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isi'],
      )!,
      penjelasan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}penjelasan'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $PasalVersiTableTable createAlias(String alias) {
    return $PasalVersiTableTable(attachedDatabase, alias);
  }
}

class PasalVersiTableData extends DataClass
    implements Insertable<PasalVersiTableData> {
  final String id;
  final String pasalId;
  final int urutan;
  final String status;
  final String? sumber;
  final String? judulSumber;
  final String? diundangkan;
  final String? berlakuSejak;
  final String? naskahResmi;
  final String isi;
  final String? penjelasan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const PasalVersiTableData({
    required this.id,
    required this.pasalId,
    required this.urutan,
    required this.status,
    this.sumber,
    this.judulSumber,
    this.diundangkan,
    this.berlakuSejak,
    this.naskahResmi,
    required this.isi,
    this.penjelasan,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pasal_id'] = Variable<String>(pasalId);
    map['urutan'] = Variable<int>(urutan);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || sumber != null) {
      map['sumber'] = Variable<String>(sumber);
    }
    if (!nullToAbsent || judulSumber != null) {
      map['judul_sumber'] = Variable<String>(judulSumber);
    }
    if (!nullToAbsent || diundangkan != null) {
      map['diundangkan'] = Variable<String>(diundangkan);
    }
    if (!nullToAbsent || berlakuSejak != null) {
      map['berlaku_sejak'] = Variable<String>(berlakuSejak);
    }
    if (!nullToAbsent || naskahResmi != null) {
      map['naskah_resmi'] = Variable<String>(naskahResmi);
    }
    map['isi'] = Variable<String>(isi);
    if (!nullToAbsent || penjelasan != null) {
      map['penjelasan'] = Variable<String>(penjelasan);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  PasalVersiTableCompanion toCompanion(bool nullToAbsent) {
    return PasalVersiTableCompanion(
      id: Value(id),
      pasalId: Value(pasalId),
      urutan: Value(urutan),
      status: Value(status),
      sumber: sumber == null && nullToAbsent
          ? const Value.absent()
          : Value(sumber),
      judulSumber: judulSumber == null && nullToAbsent
          ? const Value.absent()
          : Value(judulSumber),
      diundangkan: diundangkan == null && nullToAbsent
          ? const Value.absent()
          : Value(diundangkan),
      berlakuSejak: berlakuSejak == null && nullToAbsent
          ? const Value.absent()
          : Value(berlakuSejak),
      naskahResmi: naskahResmi == null && nullToAbsent
          ? const Value.absent()
          : Value(naskahResmi),
      isi: Value(isi),
      penjelasan: penjelasan == null && nullToAbsent
          ? const Value.absent()
          : Value(penjelasan),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory PasalVersiTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PasalVersiTableData(
      id: serializer.fromJson<String>(json['id']),
      pasalId: serializer.fromJson<String>(json['pasalId']),
      urutan: serializer.fromJson<int>(json['urutan']),
      status: serializer.fromJson<String>(json['status']),
      sumber: serializer.fromJson<String?>(json['sumber']),
      judulSumber: serializer.fromJson<String?>(json['judulSumber']),
      diundangkan: serializer.fromJson<String?>(json['diundangkan']),
      berlakuSejak: serializer.fromJson<String?>(json['berlakuSejak']),
      naskahResmi: serializer.fromJson<String?>(json['naskahResmi']),
      isi: serializer.fromJson<String>(json['isi']),
      penjelasan: serializer.fromJson<String?>(json['penjelasan']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pasalId': serializer.toJson<String>(pasalId),
      'urutan': serializer.toJson<int>(urutan),
      'status': serializer.toJson<String>(status),
      'sumber': serializer.toJson<String?>(sumber),
      'judulSumber': serializer.toJson<String?>(judulSumber),
      'diundangkan': serializer.toJson<String?>(diundangkan),
      'berlakuSejak': serializer.toJson<String?>(berlakuSejak),
      'naskahResmi': serializer.toJson<String?>(naskahResmi),
      'isi': serializer.toJson<String>(isi),
      'penjelasan': serializer.toJson<String?>(penjelasan),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  PasalVersiTableData copyWith({
    String? id,
    String? pasalId,
    int? urutan,
    String? status,
    Value<String?> sumber = const Value.absent(),
    Value<String?> judulSumber = const Value.absent(),
    Value<String?> diundangkan = const Value.absent(),
    Value<String?> berlakuSejak = const Value.absent(),
    Value<String?> naskahResmi = const Value.absent(),
    String? isi,
    Value<String?> penjelasan = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => PasalVersiTableData(
    id: id ?? this.id,
    pasalId: pasalId ?? this.pasalId,
    urutan: urutan ?? this.urutan,
    status: status ?? this.status,
    sumber: sumber.present ? sumber.value : this.sumber,
    judulSumber: judulSumber.present ? judulSumber.value : this.judulSumber,
    diundangkan: diundangkan.present ? diundangkan.value : this.diundangkan,
    berlakuSejak: berlakuSejak.present ? berlakuSejak.value : this.berlakuSejak,
    naskahResmi: naskahResmi.present ? naskahResmi.value : this.naskahResmi,
    isi: isi ?? this.isi,
    penjelasan: penjelasan.present ? penjelasan.value : this.penjelasan,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  PasalVersiTableData copyWithCompanion(PasalVersiTableCompanion data) {
    return PasalVersiTableData(
      id: data.id.present ? data.id.value : this.id,
      pasalId: data.pasalId.present ? data.pasalId.value : this.pasalId,
      urutan: data.urutan.present ? data.urutan.value : this.urutan,
      status: data.status.present ? data.status.value : this.status,
      sumber: data.sumber.present ? data.sumber.value : this.sumber,
      judulSumber: data.judulSumber.present
          ? data.judulSumber.value
          : this.judulSumber,
      diundangkan: data.diundangkan.present
          ? data.diundangkan.value
          : this.diundangkan,
      berlakuSejak: data.berlakuSejak.present
          ? data.berlakuSejak.value
          : this.berlakuSejak,
      naskahResmi: data.naskahResmi.present
          ? data.naskahResmi.value
          : this.naskahResmi,
      isi: data.isi.present ? data.isi.value : this.isi,
      penjelasan: data.penjelasan.present
          ? data.penjelasan.value
          : this.penjelasan,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PasalVersiTableData(')
          ..write('id: $id, ')
          ..write('pasalId: $pasalId, ')
          ..write('urutan: $urutan, ')
          ..write('status: $status, ')
          ..write('sumber: $sumber, ')
          ..write('judulSumber: $judulSumber, ')
          ..write('diundangkan: $diundangkan, ')
          ..write('berlakuSejak: $berlakuSejak, ')
          ..write('naskahResmi: $naskahResmi, ')
          ..write('isi: $isi, ')
          ..write('penjelasan: $penjelasan, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pasalId,
    urutan,
    status,
    sumber,
    judulSumber,
    diundangkan,
    berlakuSejak,
    naskahResmi,
    isi,
    penjelasan,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PasalVersiTableData &&
          other.id == this.id &&
          other.pasalId == this.pasalId &&
          other.urutan == this.urutan &&
          other.status == this.status &&
          other.sumber == this.sumber &&
          other.judulSumber == this.judulSumber &&
          other.diundangkan == this.diundangkan &&
          other.berlakuSejak == this.berlakuSejak &&
          other.naskahResmi == this.naskahResmi &&
          other.isi == this.isi &&
          other.penjelasan == this.penjelasan &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PasalVersiTableCompanion extends UpdateCompanion<PasalVersiTableData> {
  final Value<String> id;
  final Value<String> pasalId;
  final Value<int> urutan;
  final Value<String> status;
  final Value<String?> sumber;
  final Value<String?> judulSumber;
  final Value<String?> diundangkan;
  final Value<String?> berlakuSejak;
  final Value<String?> naskahResmi;
  final Value<String> isi;
  final Value<String?> penjelasan;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const PasalVersiTableCompanion({
    this.id = const Value.absent(),
    this.pasalId = const Value.absent(),
    this.urutan = const Value.absent(),
    this.status = const Value.absent(),
    this.sumber = const Value.absent(),
    this.judulSumber = const Value.absent(),
    this.diundangkan = const Value.absent(),
    this.berlakuSejak = const Value.absent(),
    this.naskahResmi = const Value.absent(),
    this.isi = const Value.absent(),
    this.penjelasan = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PasalVersiTableCompanion.insert({
    required String id,
    required String pasalId,
    required int urutan,
    required String status,
    this.sumber = const Value.absent(),
    this.judulSumber = const Value.absent(),
    this.diundangkan = const Value.absent(),
    this.berlakuSejak = const Value.absent(),
    this.naskahResmi = const Value.absent(),
    required String isi,
    this.penjelasan = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pasalId = Value(pasalId),
       urutan = Value(urutan),
       status = Value(status),
       isi = Value(isi);
  static Insertable<PasalVersiTableData> custom({
    Expression<String>? id,
    Expression<String>? pasalId,
    Expression<int>? urutan,
    Expression<String>? status,
    Expression<String>? sumber,
    Expression<String>? judulSumber,
    Expression<String>? diundangkan,
    Expression<String>? berlakuSejak,
    Expression<String>? naskahResmi,
    Expression<String>? isi,
    Expression<String>? penjelasan,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pasalId != null) 'pasal_id': pasalId,
      if (urutan != null) 'urutan': urutan,
      if (status != null) 'status': status,
      if (sumber != null) 'sumber': sumber,
      if (judulSumber != null) 'judul_sumber': judulSumber,
      if (diundangkan != null) 'diundangkan': diundangkan,
      if (berlakuSejak != null) 'berlaku_sejak': berlakuSejak,
      if (naskahResmi != null) 'naskah_resmi': naskahResmi,
      if (isi != null) 'isi': isi,
      if (penjelasan != null) 'penjelasan': penjelasan,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PasalVersiTableCompanion copyWith({
    Value<String>? id,
    Value<String>? pasalId,
    Value<int>? urutan,
    Value<String>? status,
    Value<String?>? sumber,
    Value<String?>? judulSumber,
    Value<String?>? diundangkan,
    Value<String?>? berlakuSejak,
    Value<String?>? naskahResmi,
    Value<String>? isi,
    Value<String?>? penjelasan,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return PasalVersiTableCompanion(
      id: id ?? this.id,
      pasalId: pasalId ?? this.pasalId,
      urutan: urutan ?? this.urutan,
      status: status ?? this.status,
      sumber: sumber ?? this.sumber,
      judulSumber: judulSumber ?? this.judulSumber,
      diundangkan: diundangkan ?? this.diundangkan,
      berlakuSejak: berlakuSejak ?? this.berlakuSejak,
      naskahResmi: naskahResmi ?? this.naskahResmi,
      isi: isi ?? this.isi,
      penjelasan: penjelasan ?? this.penjelasan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pasalId.present) {
      map['pasal_id'] = Variable<String>(pasalId.value);
    }
    if (urutan.present) {
      map['urutan'] = Variable<int>(urutan.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sumber.present) {
      map['sumber'] = Variable<String>(sumber.value);
    }
    if (judulSumber.present) {
      map['judul_sumber'] = Variable<String>(judulSumber.value);
    }
    if (diundangkan.present) {
      map['diundangkan'] = Variable<String>(diundangkan.value);
    }
    if (berlakuSejak.present) {
      map['berlaku_sejak'] = Variable<String>(berlakuSejak.value);
    }
    if (naskahResmi.present) {
      map['naskah_resmi'] = Variable<String>(naskahResmi.value);
    }
    if (isi.present) {
      map['isi'] = Variable<String>(isi.value);
    }
    if (penjelasan.present) {
      map['penjelasan'] = Variable<String>(penjelasan.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PasalVersiTableCompanion(')
          ..write('id: $id, ')
          ..write('pasalId: $pasalId, ')
          ..write('urutan: $urutan, ')
          ..write('status: $status, ')
          ..write('sumber: $sumber, ')
          ..write('judulSumber: $judulSumber, ')
          ..write('diundangkan: $diundangkan, ')
          ..write('berlakuSejak: $berlakuSejak, ')
          ..write('naskahResmi: $naskahResmi, ')
          ..write('isi: $isi, ')
          ..write('penjelasan: $penjelasan, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UndangUndangTableTable undangUndangTable =
      $UndangUndangTableTable(this);
  late final $PasalTableTable pasalTable = $PasalTableTable(this);
  late final $PasalLinksTableTable pasalLinksTable = $PasalLinksTableTable(
    this,
  );
  late final $PasalVersiTableTable pasalVersiTable = $PasalVersiTableTable(
    this,
  );
  late final Index idxPasalVersiPasalId = Index(
    'idx_pasal_versi_pasal_id',
    'CREATE INDEX idx_pasal_versi_pasal_id ON pasal_versi_table (pasal_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    undangUndangTable,
    pasalTable,
    pasalLinksTable,
    pasalVersiTable,
    idxPasalVersiPasalId,
  ];
}

typedef $$UndangUndangTableTableCreateCompanionBuilder =
    UndangUndangTableCompanion Function({
      required String id,
      required String kode,
      required String nama,
      Value<String?> namaLengkap,
      Value<String?> deskripsi,
      Value<int> tahun,
      Value<bool> isActive,
      Value<DateTime?> updatedAt,
      Value<String?> officialUrl,
      Value<String?> sourceUrl,
      Value<int> rowid,
    });
typedef $$UndangUndangTableTableUpdateCompanionBuilder =
    UndangUndangTableCompanion Function({
      Value<String> id,
      Value<String> kode,
      Value<String> nama,
      Value<String?> namaLengkap,
      Value<String?> deskripsi,
      Value<int> tahun,
      Value<bool> isActive,
      Value<DateTime?> updatedAt,
      Value<String?> officialUrl,
      Value<String?> sourceUrl,
      Value<int> rowid,
    });

class $$UndangUndangTableTableFilterComposer
    extends Composer<_$AppDatabase, $UndangUndangTableTable> {
  $$UndangUndangTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kode => $composableBuilder(
    column: $table.kode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get namaLengkap => $composableBuilder(
    column: $table.namaLengkap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deskripsi => $composableBuilder(
    column: $table.deskripsi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tahun => $composableBuilder(
    column: $table.tahun,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officialUrl => $composableBuilder(
    column: $table.officialUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UndangUndangTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UndangUndangTableTable> {
  $$UndangUndangTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kode => $composableBuilder(
    column: $table.kode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get namaLengkap => $composableBuilder(
    column: $table.namaLengkap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deskripsi => $composableBuilder(
    column: $table.deskripsi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tahun => $composableBuilder(
    column: $table.tahun,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officialUrl => $composableBuilder(
    column: $table.officialUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UndangUndangTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UndangUndangTableTable> {
  $$UndangUndangTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kode =>
      $composableBuilder(column: $table.kode, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<String> get namaLengkap => $composableBuilder(
    column: $table.namaLengkap,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deskripsi =>
      $composableBuilder(column: $table.deskripsi, builder: (column) => column);

  GeneratedColumn<int> get tahun =>
      $composableBuilder(column: $table.tahun, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get officialUrl => $composableBuilder(
    column: $table.officialUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);
}

class $$UndangUndangTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UndangUndangTableTable,
          UndangUndangTableData,
          $$UndangUndangTableTableFilterComposer,
          $$UndangUndangTableTableOrderingComposer,
          $$UndangUndangTableTableAnnotationComposer,
          $$UndangUndangTableTableCreateCompanionBuilder,
          $$UndangUndangTableTableUpdateCompanionBuilder,
          (
            UndangUndangTableData,
            BaseReferences<
              _$AppDatabase,
              $UndangUndangTableTable,
              UndangUndangTableData
            >,
          ),
          UndangUndangTableData,
          PrefetchHooks Function()
        > {
  $$UndangUndangTableTableTableManager(
    _$AppDatabase db,
    $UndangUndangTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UndangUndangTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UndangUndangTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UndangUndangTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kode = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String?> namaLengkap = const Value.absent(),
                Value<String?> deskripsi = const Value.absent(),
                Value<int> tahun = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String?> officialUrl = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UndangUndangTableCompanion(
                id: id,
                kode: kode,
                nama: nama,
                namaLengkap: namaLengkap,
                deskripsi: deskripsi,
                tahun: tahun,
                isActive: isActive,
                updatedAt: updatedAt,
                officialUrl: officialUrl,
                sourceUrl: sourceUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kode,
                required String nama,
                Value<String?> namaLengkap = const Value.absent(),
                Value<String?> deskripsi = const Value.absent(),
                Value<int> tahun = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String?> officialUrl = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UndangUndangTableCompanion.insert(
                id: id,
                kode: kode,
                nama: nama,
                namaLengkap: namaLengkap,
                deskripsi: deskripsi,
                tahun: tahun,
                isActive: isActive,
                updatedAt: updatedAt,
                officialUrl: officialUrl,
                sourceUrl: sourceUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UndangUndangTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UndangUndangTableTable,
      UndangUndangTableData,
      $$UndangUndangTableTableFilterComposer,
      $$UndangUndangTableTableOrderingComposer,
      $$UndangUndangTableTableAnnotationComposer,
      $$UndangUndangTableTableCreateCompanionBuilder,
      $$UndangUndangTableTableUpdateCompanionBuilder,
      (
        UndangUndangTableData,
        BaseReferences<
          _$AppDatabase,
          $UndangUndangTableTable,
          UndangUndangTableData
        >,
      ),
      UndangUndangTableData,
      PrefetchHooks Function()
    >;
typedef $$PasalTableTableCreateCompanionBuilder =
    PasalTableCompanion Function({
      required String id,
      required String undangUndangId,
      required String nomor,
      required String isi,
      Value<String?> penjelasan,
      Value<String?> judul,
      Value<String?> bab,
      Value<String> relatedIds,
      Value<bool> isActive,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<String> verificationStatus,
      Value<DateTime?> verifiedAt,
      Value<int> rowid,
    });
typedef $$PasalTableTableUpdateCompanionBuilder =
    PasalTableCompanion Function({
      Value<String> id,
      Value<String> undangUndangId,
      Value<String> nomor,
      Value<String> isi,
      Value<String?> penjelasan,
      Value<String?> judul,
      Value<String?> bab,
      Value<String> relatedIds,
      Value<bool> isActive,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<String> verificationStatus,
      Value<DateTime?> verifiedAt,
      Value<int> rowid,
    });

class $$PasalTableTableFilterComposer
    extends Composer<_$AppDatabase, $PasalTableTable> {
  $$PasalTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get undangUndangId => $composableBuilder(
    column: $table.undangUndangId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nomor => $composableBuilder(
    column: $table.nomor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isi => $composableBuilder(
    column: $table.isi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get penjelasan => $composableBuilder(
    column: $table.penjelasan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get judul => $composableBuilder(
    column: $table.judul,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bab => $composableBuilder(
    column: $table.bab,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relatedIds => $composableBuilder(
    column: $table.relatedIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PasalTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PasalTableTable> {
  $$PasalTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get undangUndangId => $composableBuilder(
    column: $table.undangUndangId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nomor => $composableBuilder(
    column: $table.nomor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isi => $composableBuilder(
    column: $table.isi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get penjelasan => $composableBuilder(
    column: $table.penjelasan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get judul => $composableBuilder(
    column: $table.judul,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bab => $composableBuilder(
    column: $table.bab,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedIds => $composableBuilder(
    column: $table.relatedIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PasalTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PasalTableTable> {
  $$PasalTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get undangUndangId => $composableBuilder(
    column: $table.undangUndangId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nomor =>
      $composableBuilder(column: $table.nomor, builder: (column) => column);

  GeneratedColumn<String> get isi =>
      $composableBuilder(column: $table.isi, builder: (column) => column);

  GeneratedColumn<String> get penjelasan => $composableBuilder(
    column: $table.penjelasan,
    builder: (column) => column,
  );

  GeneratedColumn<String> get judul =>
      $composableBuilder(column: $table.judul, builder: (column) => column);

  GeneratedColumn<String> get bab =>
      $composableBuilder(column: $table.bab, builder: (column) => column);

  GeneratedColumn<String> get relatedIds => $composableBuilder(
    column: $table.relatedIds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => column,
  );
}

class $$PasalTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PasalTableTable,
          PasalTableData,
          $$PasalTableTableFilterComposer,
          $$PasalTableTableOrderingComposer,
          $$PasalTableTableAnnotationComposer,
          $$PasalTableTableCreateCompanionBuilder,
          $$PasalTableTableUpdateCompanionBuilder,
          (
            PasalTableData,
            BaseReferences<_$AppDatabase, $PasalTableTable, PasalTableData>,
          ),
          PasalTableData,
          PrefetchHooks Function()
        > {
  $$PasalTableTableTableManager(_$AppDatabase db, $PasalTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PasalTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PasalTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PasalTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> undangUndangId = const Value.absent(),
                Value<String> nomor = const Value.absent(),
                Value<String> isi = const Value.absent(),
                Value<String?> penjelasan = const Value.absent(),
                Value<String?> judul = const Value.absent(),
                Value<String?> bab = const Value.absent(),
                Value<String> relatedIds = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String> verificationStatus = const Value.absent(),
                Value<DateTime?> verifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PasalTableCompanion(
                id: id,
                undangUndangId: undangUndangId,
                nomor: nomor,
                isi: isi,
                penjelasan: penjelasan,
                judul: judul,
                bab: bab,
                relatedIds: relatedIds,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                verificationStatus: verificationStatus,
                verifiedAt: verifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String undangUndangId,
                required String nomor,
                required String isi,
                Value<String?> penjelasan = const Value.absent(),
                Value<String?> judul = const Value.absent(),
                Value<String?> bab = const Value.absent(),
                Value<String> relatedIds = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String> verificationStatus = const Value.absent(),
                Value<DateTime?> verifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PasalTableCompanion.insert(
                id: id,
                undangUndangId: undangUndangId,
                nomor: nomor,
                isi: isi,
                penjelasan: penjelasan,
                judul: judul,
                bab: bab,
                relatedIds: relatedIds,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                verificationStatus: verificationStatus,
                verifiedAt: verifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PasalTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PasalTableTable,
      PasalTableData,
      $$PasalTableTableFilterComposer,
      $$PasalTableTableOrderingComposer,
      $$PasalTableTableAnnotationComposer,
      $$PasalTableTableCreateCompanionBuilder,
      $$PasalTableTableUpdateCompanionBuilder,
      (
        PasalTableData,
        BaseReferences<_$AppDatabase, $PasalTableTable, PasalTableData>,
      ),
      PasalTableData,
      PrefetchHooks Function()
    >;
typedef $$PasalLinksTableTableCreateCompanionBuilder =
    PasalLinksTableCompanion Function({
      required String id,
      required String sourcePasalId,
      required String targetPasalId,
      Value<String?> keterangan,
      Value<bool> isActive,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });
typedef $$PasalLinksTableTableUpdateCompanionBuilder =
    PasalLinksTableCompanion Function({
      Value<String> id,
      Value<String> sourcePasalId,
      Value<String> targetPasalId,
      Value<String?> keterangan,
      Value<bool> isActive,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });

class $$PasalLinksTableTableFilterComposer
    extends Composer<_$AppDatabase, $PasalLinksTableTable> {
  $$PasalLinksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePasalId => $composableBuilder(
    column: $table.sourcePasalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPasalId => $composableBuilder(
    column: $table.targetPasalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keterangan => $composableBuilder(
    column: $table.keterangan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PasalLinksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PasalLinksTableTable> {
  $$PasalLinksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePasalId => $composableBuilder(
    column: $table.sourcePasalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPasalId => $composableBuilder(
    column: $table.targetPasalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keterangan => $composableBuilder(
    column: $table.keterangan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PasalLinksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PasalLinksTableTable> {
  $$PasalLinksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourcePasalId => $composableBuilder(
    column: $table.sourcePasalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetPasalId => $composableBuilder(
    column: $table.targetPasalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keterangan => $composableBuilder(
    column: $table.keterangan,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PasalLinksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PasalLinksTableTable,
          PasalLinksTableData,
          $$PasalLinksTableTableFilterComposer,
          $$PasalLinksTableTableOrderingComposer,
          $$PasalLinksTableTableAnnotationComposer,
          $$PasalLinksTableTableCreateCompanionBuilder,
          $$PasalLinksTableTableUpdateCompanionBuilder,
          (
            PasalLinksTableData,
            BaseReferences<
              _$AppDatabase,
              $PasalLinksTableTable,
              PasalLinksTableData
            >,
          ),
          PasalLinksTableData,
          PrefetchHooks Function()
        > {
  $$PasalLinksTableTableTableManager(
    _$AppDatabase db,
    $PasalLinksTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PasalLinksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PasalLinksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PasalLinksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourcePasalId = const Value.absent(),
                Value<String> targetPasalId = const Value.absent(),
                Value<String?> keterangan = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PasalLinksTableCompanion(
                id: id,
                sourcePasalId: sourcePasalId,
                targetPasalId: targetPasalId,
                keterangan: keterangan,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourcePasalId,
                required String targetPasalId,
                Value<String?> keterangan = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PasalLinksTableCompanion.insert(
                id: id,
                sourcePasalId: sourcePasalId,
                targetPasalId: targetPasalId,
                keterangan: keterangan,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PasalLinksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PasalLinksTableTable,
      PasalLinksTableData,
      $$PasalLinksTableTableFilterComposer,
      $$PasalLinksTableTableOrderingComposer,
      $$PasalLinksTableTableAnnotationComposer,
      $$PasalLinksTableTableCreateCompanionBuilder,
      $$PasalLinksTableTableUpdateCompanionBuilder,
      (
        PasalLinksTableData,
        BaseReferences<
          _$AppDatabase,
          $PasalLinksTableTable,
          PasalLinksTableData
        >,
      ),
      PasalLinksTableData,
      PrefetchHooks Function()
    >;
typedef $$PasalVersiTableTableCreateCompanionBuilder =
    PasalVersiTableCompanion Function({
      required String id,
      required String pasalId,
      required int urutan,
      required String status,
      Value<String?> sumber,
      Value<String?> judulSumber,
      Value<String?> diundangkan,
      Value<String?> berlakuSejak,
      Value<String?> naskahResmi,
      required String isi,
      Value<String?> penjelasan,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$PasalVersiTableTableUpdateCompanionBuilder =
    PasalVersiTableCompanion Function({
      Value<String> id,
      Value<String> pasalId,
      Value<int> urutan,
      Value<String> status,
      Value<String?> sumber,
      Value<String?> judulSumber,
      Value<String?> diundangkan,
      Value<String?> berlakuSejak,
      Value<String?> naskahResmi,
      Value<String> isi,
      Value<String?> penjelasan,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$PasalVersiTableTableFilterComposer
    extends Composer<_$AppDatabase, $PasalVersiTableTable> {
  $$PasalVersiTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pasalId => $composableBuilder(
    column: $table.pasalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get urutan => $composableBuilder(
    column: $table.urutan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get judulSumber => $composableBuilder(
    column: $table.judulSumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diundangkan => $composableBuilder(
    column: $table.diundangkan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get berlakuSejak => $composableBuilder(
    column: $table.berlakuSejak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get naskahResmi => $composableBuilder(
    column: $table.naskahResmi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isi => $composableBuilder(
    column: $table.isi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get penjelasan => $composableBuilder(
    column: $table.penjelasan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PasalVersiTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PasalVersiTableTable> {
  $$PasalVersiTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pasalId => $composableBuilder(
    column: $table.pasalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get urutan => $composableBuilder(
    column: $table.urutan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get judulSumber => $composableBuilder(
    column: $table.judulSumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diundangkan => $composableBuilder(
    column: $table.diundangkan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get berlakuSejak => $composableBuilder(
    column: $table.berlakuSejak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get naskahResmi => $composableBuilder(
    column: $table.naskahResmi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isi => $composableBuilder(
    column: $table.isi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get penjelasan => $composableBuilder(
    column: $table.penjelasan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PasalVersiTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PasalVersiTableTable> {
  $$PasalVersiTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pasalId =>
      $composableBuilder(column: $table.pasalId, builder: (column) => column);

  GeneratedColumn<int> get urutan =>
      $composableBuilder(column: $table.urutan, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get sumber =>
      $composableBuilder(column: $table.sumber, builder: (column) => column);

  GeneratedColumn<String> get judulSumber => $composableBuilder(
    column: $table.judulSumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diundangkan => $composableBuilder(
    column: $table.diundangkan,
    builder: (column) => column,
  );

  GeneratedColumn<String> get berlakuSejak => $composableBuilder(
    column: $table.berlakuSejak,
    builder: (column) => column,
  );

  GeneratedColumn<String> get naskahResmi => $composableBuilder(
    column: $table.naskahResmi,
    builder: (column) => column,
  );

  GeneratedColumn<String> get isi =>
      $composableBuilder(column: $table.isi, builder: (column) => column);

  GeneratedColumn<String> get penjelasan => $composableBuilder(
    column: $table.penjelasan,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PasalVersiTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PasalVersiTableTable,
          PasalVersiTableData,
          $$PasalVersiTableTableFilterComposer,
          $$PasalVersiTableTableOrderingComposer,
          $$PasalVersiTableTableAnnotationComposer,
          $$PasalVersiTableTableCreateCompanionBuilder,
          $$PasalVersiTableTableUpdateCompanionBuilder,
          (
            PasalVersiTableData,
            BaseReferences<
              _$AppDatabase,
              $PasalVersiTableTable,
              PasalVersiTableData
            >,
          ),
          PasalVersiTableData,
          PrefetchHooks Function()
        > {
  $$PasalVersiTableTableTableManager(
    _$AppDatabase db,
    $PasalVersiTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PasalVersiTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PasalVersiTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PasalVersiTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> pasalId = const Value.absent(),
                Value<int> urutan = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> sumber = const Value.absent(),
                Value<String?> judulSumber = const Value.absent(),
                Value<String?> diundangkan = const Value.absent(),
                Value<String?> berlakuSejak = const Value.absent(),
                Value<String?> naskahResmi = const Value.absent(),
                Value<String> isi = const Value.absent(),
                Value<String?> penjelasan = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PasalVersiTableCompanion(
                id: id,
                pasalId: pasalId,
                urutan: urutan,
                status: status,
                sumber: sumber,
                judulSumber: judulSumber,
                diundangkan: diundangkan,
                berlakuSejak: berlakuSejak,
                naskahResmi: naskahResmi,
                isi: isi,
                penjelasan: penjelasan,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String pasalId,
                required int urutan,
                required String status,
                Value<String?> sumber = const Value.absent(),
                Value<String?> judulSumber = const Value.absent(),
                Value<String?> diundangkan = const Value.absent(),
                Value<String?> berlakuSejak = const Value.absent(),
                Value<String?> naskahResmi = const Value.absent(),
                required String isi,
                Value<String?> penjelasan = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PasalVersiTableCompanion.insert(
                id: id,
                pasalId: pasalId,
                urutan: urutan,
                status: status,
                sumber: sumber,
                judulSumber: judulSumber,
                diundangkan: diundangkan,
                berlakuSejak: berlakuSejak,
                naskahResmi: naskahResmi,
                isi: isi,
                penjelasan: penjelasan,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PasalVersiTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PasalVersiTableTable,
      PasalVersiTableData,
      $$PasalVersiTableTableFilterComposer,
      $$PasalVersiTableTableOrderingComposer,
      $$PasalVersiTableTableAnnotationComposer,
      $$PasalVersiTableTableCreateCompanionBuilder,
      $$PasalVersiTableTableUpdateCompanionBuilder,
      (
        PasalVersiTableData,
        BaseReferences<
          _$AppDatabase,
          $PasalVersiTableTable,
          PasalVersiTableData
        >,
      ),
      PasalVersiTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UndangUndangTableTableTableManager get undangUndangTable =>
      $$UndangUndangTableTableTableManager(_db, _db.undangUndangTable);
  $$PasalTableTableTableManager get pasalTable =>
      $$PasalTableTableTableManager(_db, _db.pasalTable);
  $$PasalLinksTableTableTableManager get pasalLinksTable =>
      $$PasalLinksTableTableTableManager(_db, _db.pasalLinksTable);
  $$PasalVersiTableTableTableManager get pasalVersiTable =>
      $$PasalVersiTableTableTableManager(_db, _db.pasalVersiTable);
}
