
=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::MetaData::AnnotationAnalyzer

=head1 SYNOPSIS

my $anal = Bio::EnsEMBL::MetaData::AnnotationAnalyzer->new();
my $details = $anal->analyze_annotation($dba);

=head1 DESCRIPTION

Utility class for counting xrefs, variations etc. associated with a genome

=head1 AUTHOR

Dan Staines

=cut

use strict;
use warnings;

package Bio::EnsEMBL::MetaData::AnnotationAnalyzer;
use Bio::EnsEMBL::Utils::Exception qw/throw/;

use Log::Log4perl qw(get_logger);
use Data::Dumper;
use Config::IniFiles;
use LWP::UserAgent;
my $ua = LWP::UserAgent->new();

my $url_template =
'https://raw.github.com/EnsemblGenomes/eg-web-DIVISION/master/conf/ini-files/SPECIES.ini';

=head1 SUBROUTINES/METHODS

=head2 new
  Description: Return a new instance of AnnotationAnalyzer
  Returntype : Bio::EnsEMBL::MetaData::AnnotationAnalyzer
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub new {
  my $caller = shift;
  my $class  = ref($caller) || $caller;
  my $self   = bless( {}, $class );
  $self->{logger} = get_logger();
  return $self;
}

=head2 analyze_annotation
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Description: Analyzes annotation content of the supplied core DB
  Returntype : 	Hash ref with the following keys:
					nProteinCoding - number of protein coding genes
					nProteinCodingUniProtKBSwissProt - number of protein coding genes with at least one SwissPROT entry
					nProteinCodingUniProtKBTrEMBL - number of protein coding genes with at least one TrEMBL entry
					nProteinCodingGO - number of protein coding genes with at least one GO term
					nProteinCodingInterPro - number of protein coding genes with at least one InterPro match
					nUniProtKBSwissProt - number of distinct UniProtKB/TrEMBL entries matching at least one translation
					nUniProtKBTrEMBL - number of distinct UniProtKB/TrEMBL entries matching at least one translation
					nGO - number of distinct GO terms matching at least one translation
					nInterPro - number of distinct InterPro entries matching at least one feature
					nInterProDomains - number of distinct protein features matching an InterPro domains
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub analyze_annotation {
  my ( $self, $dba ) = @_;
  $self->{logger}->debug( "Analysing annotation for " . $dba->species() );
  my $ann = {
      nProteinCoding => $self->count_by_biotype( $dba, 'protein_coding' ),
      nProteinCodingGO => $self->count_by_xref( $dba, ['GO'], 'protein_coding' ),
      nProteinCodingUniProtKB =>
        $self->count_by_xref( $dba, [ 'Uniprot/SWISSPROT', 'Uniprot/SPTREMBL' ],
                              'protein_coding' ),
      nProteinCodingUniProtKBSwissProt =>
        $self->count_by_xref( $dba, ['Uniprot/SWISSPROT'], 'protein_coding' ),
      nProteinCodingUniProtKBTrEMBL =>
        $self->count_by_xref( $dba, ['Uniprot/SPTREMBL'], 'protein_coding' ),
      nProteinCodingInterPro => $self->count_by_interpro($dba),
      nGO => $self->count_by_xref( $dba, ['GO']),
      nUniProtKBSwissProt => $self->count_xrefs( $dba, ['Uniprot/SWISSPROT'] ),
      nUniProtKBTrEMBL    => $self->count_xrefs( $dba, ['Uniprot/SPTREMBL'] ),
      nInterPro           => $self->count_interpro($dba),
      nInterProDomains => $self->count_interpro_domains($dba) };
  # add metadata
  my $meta = $dba->get_MetaContainer();
  for my $key (qw/genebuild.method provider.name/) {
    for my $value (@{$meta->list_value_by_key($key)}) {
      (my $k = $key) =~ s/\./_/g;
      $ann->{$k} = $value if defined $value;
    }
  }
  return $ann;
}

=head2 analyze_features
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Description: Analyzes features found in the supplied core/otherfeatures database (simple_feature,repeat_feature,protein_align_feature,dna_align_features)
  Returntype : 	Hash ref (keys are feature tables, values are hashrefs of count by analysis name)
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub analyze_features {
  my ( $self, $dba ) = @_;
  return { simpleFeatures => $self->count_features( $dba, 'simple_feature' ),
           repeatFeatures => $self->count_features( $dba, 'repeat_feature' ) };
}

=head2 analyze_variation
  Arg        : Bio::EnsEMBL::Variation::DBSQL::DBAdaptor
  Description: Analyzes variation found in the supplied variation database
  Returntype : 	Hash ref with the following keys
					variations - count of variations per source
					structuralVariations - count of structural variations per source
					genotypes - count of genotypes per sample
					phenotypes - count of variation annotations per phenotype
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub analyze_variation {
  my ( $self, $dba ) = @_;
  return { variations           => $self->count_variations($dba),
           structuralVariations => $self->count_structural_variations($dba),
           genotypes            => $self->count_genotypes($dba),
           phenotypes           => $self->count_phenotypes($dba) };
}

=head2 analyze_compara
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Arg        : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
  Description: Analyzes compara methods found in the supplied compara database involving the supplied core species
  Returntype : 	Hash ref (keys are method names, values are arrays of partner species)
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub analyze_compara {
  my ( $self, $dba, $core ) = @_;
  my $compara = {};
  eval {
    my $gdb =
      $dba->get_GenomeDBAdaptor()->fetch_by_registry_name( $core->species() );
    for my $mlss (
       @{ $dba->get_MethodLinkSpeciesSetAdaptor()->fetch_all_by_GenomeDB($gdb) }
      )
    {
      my $t = $mlss->method()->type();
      next
        if ( $t eq 'FAMILY' ||
             $t eq 'ENSEMBL_ORTHOLOGUES' ||
             $t eq 'ENSEMBL_PARALOGUES' );
      for my $gdb2 ( grep { $gdb->dbID() ne $_->dbID() }
                     @{ $mlss->species_set_obj->genome_dbs() } )
      {
        push( @{ $compara->{$t} }, $gdb2->name() );
      }
    }
  };
  if ($@) {
    warn "No compara entry found for " . $dba->species();
  }
  return $compara;
} ## end sub analyze_compara

=head2 analyze_alignments
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Description: Analyzes alignments for sequences to the assembly 
  Returntype : Hash ref - keys are source_type (e.g. RNA seq), values are arrayrefs of hashrefs containing track details (source_name,description,source_url)
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub analyze_alignments {
  my ( $self, $dba ) = @_;
  my $ali = {};
  my $pf = $self->count_features( $dba, 'protein_align_feature' );
  if ( scalar( keys %$pf ) > 0 ) {
    $ali->{proteinAlignFeatures} = $pf;
  }
  my $df = $self->count_features( $dba, 'dna_align_feature' );
  if ( scalar( keys %$df ) > 0 ) {
    $ali->{dnaAlignFeatures} = $df;
  }
  return $ali;
}

=head2 analyze_tracks
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Description: Analyzes tracks attached to the supplied core database
  Returntype : Hash ref - keys are source_type (e.g. RNA seq), values are arrayrefs of hashrefs containing track details (source_name,description,source_url)
  Exceptions : none
  Caller     : general
  Status     : Stable	
=cut

sub analyze_tracks {
  my ( $self, $species, $division ) = @_;
  $species = ucfirst($species);
  ( $division = lc $division ) =~ s/ensembl//;
  # get the ini file from git
  ( my $ini_url = $url_template ) =~ s/SPECIES/$species/;
  $ini_url =~ s/DIVISION/$division/;

  my $req = HTTP::Request->new( GET => $ini_url );
  # Pass request to the user agent and get a response back
  my $res = $ua->request($req);
  my $ini;
  # Check the outcome of the response
  if ( $res->is_success ) {
    $ini = $res->content;
  }
  else {
    $self->{logger}
      ->debug( "Could not retrieve $ini_url: " . $res->status_line );
  }

# parse out and look at:
# [ENSEMBL_INTERNAL_BAM_SOURCES]
# 1_Puccinia_triticina_SRR035315 = dna_align_est
# walk through keys and use keys to find sections like:
# [1_Puccinia_triticina_SRR035315]
# source_name        = Transcriptomics sequences of fresh spores. Run id: SRR035315
# description        = RNA-Seq study.
# source_url         = http://ftp.sra.ebi.ac.uk/vol1/ERZ000/ERZ000002/SRR035315.bam
# source_type        = rnaseq
# display            = normal
# then store some or all of this in my output e.g. {bam}{source_type}[{source_name,description,source_url}]
  my $bams = {};
  if ( defined $ini ) {
    my $cfg = Config::IniFiles->new( -file => \$ini );
    if ( defined $cfg ) {
      for my $bam ( $cfg->Parameters("ENSEMBL_INTERNAL_BAM_SOURCES") ) {
        push @{ $bams->{ $cfg->val( $bam, 'source_type' ) } }, {
            id          => $bam,
            source_name => $cfg->val( $bam, 'source_name' ),
            source_url  => $cfg->val( $bam, 'source_url' ),
            description => $cfg->val( $bam, 'description' ) };
      }
    }
  }
  return $bams;
} ## end sub analyze_tracks

=head2 count_by_biotype
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Arg        : String (biotype)
  Description: Returns count of genes with specified biotype
  Returntype : Integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub count_by_biotype {
  my ( $self, $dba, $biotype ) = @_;
  return $dba->get_GeneAdaptor()->count_all_by_biotype($biotype);
}

=head2 count_by_xref
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Arg        : Arrayref of dbnames 
  Arg        : (optional) String (biotype)
  Description: Returns count of genes with specified cross-reference
  Returntype : Integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $xref_gene_sql = q/select count(distinct(gene_id))
from gene g
join seq_region s using (seq_region_id)
join coord_system c using (coord_system_id)
join transcript tr using (gene_id)
join translation t using (transcript_id)
join object_xref ox on (ox.ensembl_id=g.gene_id and ox.ensembl_object_type='Gene')
join xref x using (xref_id)
join external_db d using (external_db_id)
where species_id=? and d.db_name=?/;

my $xref_transcript_sql = q/select count(distinct(gene_id))
from gene g
join seq_region s using (seq_region_id)
join coord_system c using (coord_system_id)
join transcript tr using (gene_id)
join translation t using (transcript_id)
join object_xref ox on (ox.ensembl_id=tr.transcript_id and ox.ensembl_object_type='Transcript')
join xref x using (xref_id)
join external_db d using (external_db_id)
where species_id=? and d.db_name=?/;

my $xref_translation_sql = q/select count(distinct(gene_id))
from gene g
join seq_region s using (seq_region_id)
join coord_system c using (coord_system_id)
join transcript tr using (gene_id)
join translation t using (transcript_id)
join object_xref ox on (ox.ensembl_id=t.translation_id and ox.ensembl_object_type='Translation')
join xref x using (xref_id)
join external_db d using (external_db_id)
where species_id=? and d.db_name=?/;

my $xref_level_sql = q/select distinct object_xref.ensembl_object_type
from object_xref
join xref on (object_xref.xref_id=xref.xref_id)
join .external_db on (xref.external_db_id=external_db.external_db_id)
where external_db.db_name=?/;

my $biotype_clause = q/ and g.biotype=?/;

sub count_by_xref {
  my ( $self, $dba, $db_names, $biotype ) = @_;
  my $tot  = 0;
  foreach my $db_name (@$db_names){
    my $xref_level = $dba->dbc()->sql_helper()
      ->execute_single_result( -SQL => $xref_level_sql, -PARAMS => [$db_name] );
    $self->{logger}->debug( "Counting genes by " .
                        $db_name . " xref on ".$xref_level." for " . $dba->species() );
    my $sql;
    if ($xref_level eq "Gene")
    {
      $sql=$xref_gene_sql;
    }
    elsif ($xref_level eq "Transcript"){
      $sql=$xref_transcript_sql;
    }
    elsif ($xref_level eq "Translation"){
      $sql=$xref_translation_sql;
    }
    my $params = [ $dba->species_id(), $db_name ];
    if ( defined $biotype ) {
      $sql .= $biotype_clause;
      push @$params, $biotype;
    }
    $self->{logger}
      ->debug( "Executing $sql with params: [" . join( ",", @$params ) );
    $tot += $dba->dbc()->sql_helper()
      ->execute_single_result( -SQL => $sql, -PARAMS => $params );
  }
  return $tot;
}

=head2 count_xrefs
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Arg        : One or more dbnames
  Description: Returns count of numbers of cross-references to supplied database(s)
  Returntype : Integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $gene_xref_count_sql = q/
select count(distinct(dbprimary_acc))
from gene g
join seq_region s using (seq_region_id)
join coord_system c using (coord_system_id)
join object_xref ox on (ox.ensembl_id=g.gene_id and ox.ensembl_object_type='Gene')
join xref x using (xref_id)
join external_db d using (external_db_id)
where species_id=? and d.db_name=?/;

my $transcript_xref_count_sql = q/
select count(distinct(dbprimary_acc))
from transcript tr
join seq_region s using (seq_region_id)
join coord_system c using (coord_system_id)
join object_xref ox on (ox.ensembl_id=tr.transcript_id and ox.ensembl_object_type='Transcript')
join xref x using (xref_id)
join external_db d using (external_db_id)
where species_id=? and d.db_name=?/;

my $translation_xref_count_sql = q/
select count(distinct(dbprimary_acc))
from transcript tr
join translation t using (transcript_id)
join seq_region s using (seq_region_id)
join coord_system c using (coord_system_id)
join object_xref ox on (ox.ensembl_id=t.translation_id and ox.ensembl_object_type='Translation')
join xref x using (xref_id)
join external_db d using (external_db_id)
where species_id=? and d.db_name=?/;

sub count_xrefs {
  my ($self,$dba,$db_names) = @_;
  my $tot  = 0;
  for my $db_name (@$db_names) {
    my $xref_level = $dba->dbc()->sql_helper()
      ->execute_single_result( -SQL => $xref_level_sql, -PARAMS => [$db_name] );
    if ($xref_level eq "Gene")
    {
      $tot +=
      $dba->dbc()->sql_helper()->execute_single_result(
                                     -SQL    => $gene_xref_count_sql,
                                     -PARAMS => [ $dba->species_id(), $db_name ]
      );
    }
    elsif ($xref_level eq "Transcript"){
      $tot +=
      $dba->dbc()->sql_helper()->execute_single_result(
                                     -SQL    => $transcript_xref_count_sql,
                                     -PARAMS => [ $dba->species_id(), $db_name ]
      );
    }
    elsif ($xref_level eq "Translation"){
      $tot +=
      $dba->dbc()->sql_helper()->execute_single_result(
                                     -SQL    => $translation_xref_count_sql,
                                     -PARAMS => [ $dba->species_id(), $db_name ]
      );
    }
  }
  return $tot;
}

=head2 count_by_interpro
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Description: Returns count of genes with InterPro domains
  Returntype : Integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $count_by_interpro_base = q/ from interpro
join protein_feature on (id=hit_name)
join translation using (translation_id)
join transcript using (transcript_id)
join seq_region using (seq_region_id)
join coord_system using (coord_system_id)
where species_id=?
/;

my $count_by_interpro =
  'select count(distinct(interpro_ac)) ' . $count_by_interpro_base;

sub count_by_interpro {
  my ( $self, $dba ) = @_;
  return
    $dba->dbc()->sql_helper()->execute_single_result(
                                               -SQL    => $count_by_interpro,
                                               -PARAMS => [ $dba->species_id() ]
    );
}

=head2 count_interpro
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Description: Returns count of InterPro cross-references
  Returntype : Integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $count_interpro =
  q/select count(distinct(translation_id)) / . $count_by_interpro_base;

sub count_interpro {
  my ( $self, $dba ) = @_;
  return
    $dba->dbc()->sql_helper()->execute_single_result(
                                               -SQL    => $count_interpro,
                                               -PARAMS => [ $dba->species_id() ]
    );
}

=head2 count_interpro_domains
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Description: Returns count of InterPro domains
  Returntype : Integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $count_interpro_domains =
  q/select count(distinct(protein_feature_id)) / . $count_by_interpro_base;

sub count_interpro_domains {
  my ( $self, $dba ) = @_;
  return
    $dba->dbc()->sql_helper()->execute_single_result(
                                               -SQL => $count_interpro_domains,
                                               -PARAMS => [ $dba->species_id() ]
    );
}

=head2 count_toplevel
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Description: Returns count of top-level regions
  Returntype : Integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $count_toplevel = q/select count(*) from seq_region 
join seq_region_attrib using (seq_region_id) 
join coord_system using (coord_system_id) 
join attrib_type using (attrib_type_id)
where species_id=? and code='toplevel'/;

sub count_toplevel {
  my ( $self, $dba ) = @_;
  return
    $dba->dbc()->sql_helper()->execute_single_result(
                                               -SQL    => $count_toplevel,
                                               -PARAMS => [ $dba->species_id() ]
    );
}

=head2 count_features
  Arg        : Bio::EnsEMBL::DBSQL::DBAdaptor
  Arg        : String - feature type (e.g. RepeatFeature)
  Description: Returns count of specified feature by analysis
  Returntype : Hashref
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $count_features = q/select logic_name,count(*) 
from TABLE join analysis using (analysis_id) 
join seq_region using (seq_region_id) 
join coord_system using (coord_system_id) 
where species_id=? group by logic_name/;

sub count_features {
  my ( $self, $dba, $table ) = @_;
  my $sql = $count_features;
  $sql =~ s/TABLE/$table/;
  return $dba->dbc()->sql_helper()
    ->execute_into_hash( -SQL => $sql, -PARAMS => [ $dba->species_id() ] );
}

=head2 count_variations
  Arg        : Bio::EnsEMBL::Variation::DBSQL::DBAdaptor
  Description: Returns count of variations by source
  Returntype : Hashref
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $count_variation = q/select ifnull(s.name,"unknown"),count(*) 
from variation v 
join source s using (source_id) 
group by s.name/;

sub count_variations {
  my ( $self, $dba ) = @_;
  return $dba->dbc()->sql_helper()
    ->execute_into_hash( -SQL => $count_variation, -PARAMS => [] );
}

=head2 count_structural_variations
  Arg        : Bio::EnsEMBL::Variation::DBSQL::DBAdaptor
  Description: Returns count of structural variations by source
  Returntype : Hashref
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $count_structural_variation = q/select ifnull(s.name,"unknown"),count(*) 
from structural_variation v 
join source s using (source_id) 
group by s.name/;

sub count_structural_variations {
  my ( $self, $dba ) = @_;
  return $dba->dbc()->sql_helper()
    ->execute_into_hash( -SQL => $count_structural_variation, -PARAMS => [] );
}

=head2 count_genotypes
  Arg        : Bio::EnsEMBL::Variation::DBSQL::DBAdaptor
  Description: Returns count of genotypes by source
  Returntype : Hashref
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $count_genotypes = q/
select ifnull(name,"unknown"),count(*) 
from tmp_individual_genotype_single_bp 
join individual using (individual_id) group by name/;

sub count_genotypes {
  my ( $self, $dba ) = @_;
  my $cnt = {};
  eval {
    $cnt =
      $dba->dbc()->sql_helper()
      ->execute_into_hash( -SQL => $count_genotypes, -PARAMS => [] );
  };
  return $cnt;
}

=head2 count_phenotypes
  Arg        : Bio::EnsEMBL::Variation::DBSQL::DBAdaptor
  Description: Returns count of phenotypes by name
  Returntype : Integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

my $count_phenotypes = q/
select ifnull(p.name,"unknown"),count(*) 
from phenotype p 
join phenotype_feature pf using (phenotype_id) 
join variation v on (object_id=v.name and type='Variation') 
group by p.name;
/;

sub count_phenotypes {
  my ( $self, $dba ) = @_;
  return $dba->dbc()->sql_helper()
    ->execute_into_hash( -SQL => $count_phenotypes, -PARAMS => [] );
}

1;
