
=pod
=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::Utils::MetaData::AnnotationAnalyzer;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use LWP::Simple;
use Data::Dumper;

my $url_template = 'http://cvs.sanger.ac.uk/cgi-bin/viewvc.cgi/eg-plugins/DIVISION/conf/ini-files/SPECIES.ini?root=ensembl&view=co';

sub new {
  my $caller = shift;
  my $class  = ref($caller) || $caller;
  my $self   = bless({}, $class);
  $self->{logger} = get_logger();
  return $self;
}

sub analyze_annotation {
  my ($self, $dba) = @_;
  return {
	nProteinCoding => $self->count_by_biotype($dba, 'protein_coding'),
	nProteinCodingGO => $self->count_by_xref($dba, 'GO', 'protein_coding'),
	nProteinCodingUniProtKB => $self->count_by_xref($dba, ['Uniprot/SWISSPROT', 'Uniprot/SPTREMBL'], 'protein_coding'),
	nProteinCodingUniProtKBSwissProt => $self->count_by_xref($dba, 'Uniprot/SWISSPROT', 'protein_coding'),
	nProteinCodingUniProtKBTrEMBL    => $self->count_by_xref($dba, 'Uniprot/SPTREMBL',  'protein_coding'),
	nProteinCodingInterPro           => $self->count_by_interpro($dba),
	nGO                              => $self->count_by_xref($dba, 'GO',                'protein_coding'),
	nUniProtKBSwissProt => $self->count_xrefs($dba, 'Uniprot/SWISSPROT'),
	nUniProtKBTrEMBL    => $self->count_xrefs($dba, 'Uniprot/SPTREMBL'),
	nInterPro           => $self->count_interpro($dba),
	nInterProDomains    => $self->count_interpro_domains($dba)};
}

sub analyze_features {
  my ($self, $dba) = @_;
  return {simpleFeatures       => $self->count_features($dba, 'simple_feature'),
		  repeatFeatures       => $self->count_features($dba, 'repeat_feature'),
		  proteinAlignFeatures => $self->count_features($dba, 'protein_align_feature'),
		  dnaAlignFeatures     => $self->count_features($dba, 'dna_align_feature')};
}

sub analyze_variation {
  my ($self, $dba) = @_;
  return {variations           => $self->count_variations($dba),
		  structuralVariations => $self->count_structural_variations($dba),
		  genotypes            => $self->count_genotypes($dba),
		  phenotypes           => $self->count_phenotypes($dba)};
}

sub analyze_compara {
  my ($self, $dba, $core) = @_;
  my $compara = {};
  my $gdb     = $dba->get_GenomeDBAdaptor()->fetch_by_registry_name($core->species());
  for my $mlss (@{$dba->get_MethodLinkSpeciesSetAdaptor()->fetch_all_by_GenomeDB($gdb)}) {
	my $t = $mlss->method()->type();
	for my $gdb2 (grep { $gdb->dbID() ne $_->dbID() } @{$mlss->species_set_obj->genome_dbs()}) {
	  push(@{$compara->{$t}}, $gdb2->name());
	}
  }
  return $compara;
}

sub analyze_tracks {
  my ($self, $species, $division) = @_;
  $species = ucfirst($species);
  ($division = lc $division) =~ s/ensembl//;
  # get the ini file from CVS
  (my $ini_url = $url_template) =~ s/SPECIES/$species/;
  $ini_url =~ s/DIVISION/$division/;
  my $ini = get($ini_url);
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
  my $cfg = Config::IniFiles->new(-file => \$ini);
  if(defined $cfg) {
  for my $bam ($cfg->Parameters("ENSEMBL_INTERNAL_BAM_SOURCES")) {
	push @{$bams->{$cfg->val($bam, 'source_type')}}, {
	   id          => $bam,
	   source_name => $cfg->val($bam, 'source_name'),
	   source_url  => $cfg->val($bam, 'source_url'),
	   description => $cfg->val($bam, 'description')};
  }
  }
  return $bams;
} ## end sub analyze_tracks

sub count_by_biotype {
  my ($self, $dba, $biotype) = @_;
  return $dba->get_GeneAdaptor()->count_all_by_biotype($biotype);
}

my $xref_gene_sql = q/select count(distinct(gene_id)) 
from gene g
join seq_region s using (seq_region_id) 
join coord_system c using (coord_system_id) 
join transcript tr using (gene_id)
join translation t using (transcript_id)
join object_xref ox on (ox.ensembl_id=t.translation_id and ox.ensembl_object_type='Translation')
join xref x using (xref_id)
join external_db d using (external_db_id)
where species_id=? and d.db_name in (NAMES)/;

my $biotype_clause = q/ and g.biotype=?/;

sub count_by_xref {
  my ($self, $dba, $db_names, $biotype) = @_;
  $db_names = [$db_names] if (ref($db_names) ne 'ARRAY');
  my $sql = $xref_gene_sql;
  my $db_name = join ',', map { "\"$_\"" } @$db_names;
  $sql =~ s/NAMES/$db_name/;
  my $params = [$dba->species_id()];
  if (defined $biotype) {
	$sql .= $biotype_clause;
	push @$params, $biotype;
  }
  return $dba->dbc()->sql_helper()->execute_single_result(-SQL => $sql, -PARAMS => $params);
}

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
  my $self = shift;
  my $dba  = shift;
  my $tot  = 0;
  for my $db_name (@_) {
	$tot += $dba->dbc()->sql_helper()->execute_single_result(-SQL    => $gene_xref_count_sql,
															 -PARAMS => [$dba->species_id(), $db_name]);
	$tot += $dba->dbc()->sql_helper()->execute_single_result(-SQL    => $transcript_xref_count_sql,
															 -PARAMS => [$dba->species_id(), $db_name]);
	$tot += $dba->dbc()->sql_helper()->execute_single_result(-SQL    => $translation_xref_count_sql,
															 -PARAMS => [$dba->species_id(), $db_name]);
  }
  return $tot;
}

my $count_by_interpro_base = q/ from interpro
join protein_feature on (id=hit_name)
join translation using (translation_id)
join transcript using (transcript_id)
join seq_region using (seq_region_id)
join coord_system using (coord_system_id)
where species_id=?
/;

my $count_by_interpro = 'select count(distinct(interpro_ac)) ' . $count_by_interpro_base;

sub count_by_interpro {
  my ($self, $dba) = @_;
  return $dba->dbc()->sql_helper()->execute_single_result(-SQL => $count_by_interpro, -PARAMS => [$dba->species_id()]);
}

my $count_interpro = q/select count(distinct(translation_id)) / . $count_by_interpro_base;

sub count_interpro {
  my ($self, $dba) = @_;
  return $dba->dbc()->sql_helper()->execute_single_result(-SQL => $count_interpro, -PARAMS => [$dba->species_id()]);
}

my $count_interpro_domains = q/select count(distinct(protein_feature_id)) / . $count_by_interpro_base;

sub count_interpro_domains {
  my ($self, $dba) = @_;
  return $dba->dbc()->sql_helper()->execute_single_result(-SQL => $count_interpro_domains, -PARAMS => [$dba->species_id()]);
}

my $count_toplevel = q/select count(*) from seq_region 
join seq_region_attrib using (seq_region_id) 
join coord_system using (coord_system_id) 
join attrib_type using (attrib_type_id)
where species_id=? and code='toplevel'/;

sub count_toplevel {
  my ($self, $dba) = @_;
  return $dba->dbc()->sql_helper()->execute_single_result(-SQL => $count_toplevel, -PARAMS => [$dba->species_id()]);
}

my $count_features = q/select logic_name,count(*) 
from TABLE join analysis using (analysis_id) 
join seq_region using (seq_region_id) 
join coord_system using (coord_system_id) 
where species_id=? group by logic_name/;

sub count_features {
  my ($self, $dba, $table) = @_;
  my $sql = $count_features;
  $sql =~ s/TABLE/$table/;
  return $dba->dbc()->sql_helper()->execute_into_hash(-SQL => $sql, -PARAMS => [$dba->species_id()]);
}

my $count_variation = q/select s.name,count(*) 
from variation v 
join source s using (source_id) 
group by s.name/;

sub count_variations {
  my ($self, $dba) = @_;
  return $dba->dbc()->sql_helper()->execute_into_hash(-SQL => $count_variation, -PARAMS => []);
}

my $count_structural_variation = q/select s.name,count(*) 
from structural_variation v 
join source s using (source_id) 
group by s.name/;

sub count_structural_variations {
  my ($self, $dba) = @_;
  return $dba->dbc()->sql_helper()->execute_into_hash(-SQL => $count_structural_variation, -PARAMS => []);
}

my $count_genotypes = q/
select name,count(*) 
from tmp_individual_genotype_single_bp 
join sample using (sample_id) group by name/;

sub count_genotypes {
  my ($self, $dba) = @_;
  return $dba->dbc()->sql_helper()->execute_into_hash(-SQL => $count_genotypes, -PARAMS => []);
}

my $count_phenotypes = q/
select name,count(*)
from phenotype
join variation_annotation using (phenotype_id)
group by name
/;

sub count_phenotypes {
  my ($self, $dba) = @_;
  return $dba->dbc()->sql_helper()->execute_into_hash(-SQL => $count_phenotypes, -PARAMS => []);
}

1;

__END__

=pod
=head1 NAME

Bio::EnsEMBL::Utils::MetaData::AnnotationAnalyzer

=head1 SYNOPSIS

=head1 DESCRIPTION

Utility class for counting xrefs etc.

=head1 SUBROUTINES/METHODS

=head2 new
Description:	Return a new instance of AnnotationAnalyzer
Return:			Bio::EnsEMBL::Utils::MetaData::AnnotationAnalyzer

=head2 analyze_annotation
Description:	Analyzes annotation content of the supplied core DBA
Argument:		Core DBAdaptor
Return:			Hash ref with the following keys:
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

=head2 analyze_features
Description:	Analyzes features found in the supplied core/otherfeatures database (simple_feature,repeat_feature,protein_align_feature,dna_align_features)
Argument:		DBAdaptor
Return:			Hash ref (keys are feature tables, values are hashrefs of count by analysis name)

=head2 analyze_tracks
Description:	Analyzes tracks attached to the supplied core database 
Argument:		DBAdaptor
Return:			Hash ref - keys are source_type (e.g. RNA seq), values are arrayrefs of hashrefs containing track details (source_name,description,source_url)

=head2 analyze_variation
Description:	Analyzes variation found in the supplied variation database
Argument:		Variation DBAdaptor
Return:			Hash ref with the following keys
					variations - count of variations per source
					structuralVariations - count of structural variations per source
					genotypes - count of genotypes per sample
					phenotypes - count of variation annotations per phenotype
		  
=head2 analyze_compara
Description:	Analyzes compara methods found in the supplied compara database involving the supplied core species
Argument:		Compara DBAdaptor
Argument:		Core DBAdaptor
Return:			Hash ref (keys are method names, values are arrays of partner species)

=head2 count_by_biotype

=head2 count_by_interpro

=head2 count_by_xref

=head2 count_xrefs

=head2 count_interpro

=head2 count_interpro_domains

=head2 count_features

=head2 count_variations

=head2 count_structural_variations

=head2 count_genotypes

=head2 count_phenotypes

=head2 count_toplevel

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
