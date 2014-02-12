
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

package Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;

use strict;
use warnings;
use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::MetaData::GenomeInfo;
use Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo;
use Data::Dumper;
use List::MoreUtils qw/natatime/;

sub new {
  my ($proto, @args) = @_;
  my $self = bless {}, $proto;
  ($self->{dbc}) = rearrange(['DBC'], @args);
  return $self;
}

sub _cache {
  my ($self, $type) = @_;
  if (!defined $self->{cache} || !defined $self->{cache}{$type}) {
	$self->{cache}{$type} = {};
  }
  return $self->{cache}{$type};
}

sub _clear_cache {
  my ($self, $type) = @_;
  if (defined $type) {
	$self->{cache}{$type} = {};
  }
  else {
	$self->{cache} = {};
  }
  return;
}

sub _get_cached_obj {
  my ($self, $type, $id) = @_;
  return $self->_cache($type)->{$id};
}

sub _store_cached_obj {
  my ($self, $type, $obj) = @_;
  $self->_cache($type)->{$obj->dbID()} = $obj;
  return;
}

sub store {
  my ($self, $genome) = @_;
  return if defined $genome->dbID();
  $self->{dbc}->sql_helper()->execute_update(
	-SQL =>
q/insert into genome(name,species,strain,serotype,division,taxonomy_id,
assembly_id,assembly_name,assembly_level,base_count,
genebuild,dbname,species_id,has_pan_compara,has_variation,has_peptide_compara,
has_genome_alignments,has_other_alignments)
		values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)/,
	-PARAMS => [$genome->name(),
				$genome->species(),
				$genome->strain(),
				$genome->serotype(),
				$genome->division(),
				$genome->taxonomy_id(),
				$genome->assembly_id(),
				$genome->assembly_name(),
				$genome->assembly_level(),
				$genome->base_count(),
				$genome->genebuild(),
				$genome->dbname(),
				$genome->species_id(),
				$genome->has_pan_compara(),
				$genome->has_variations(),
				$genome->has_peptide_compara(),
				$genome->has_genome_alignments(),
				$genome->has_other_alignments()],
	-CALLBACK => sub {
	  my ($sth, $dbh, $rv) = @_;
	  $genome->dbID($dbh->{mysql_insertid});
	});
  $genome->adaptor($self);
  $self->_store_aliases($genome);
  $self->_store_sequences($genome);
  $self->_store_annotations($genome);
  $self->_store_features($genome);
  $self->_store_variations($genome);
  $self->_store_alignments($genome);
  if (defined $genome->compara()) {

	for my $compara (@{$genome->compara()}) {
	  $self->_store_compara($compara);
	}
  }
  return;
} ## end sub store

sub _store_compara {
  my ($self, $compara) = @_;
  return if !defined $compara || defined $compara->dbID();
  $self->{dbc}->sql_helper()->execute_update(
	-SQL => q/insert into compara_analysis(method,division,dbname)
		values(?,?,?)/,
	-PARAMS =>
	  [$compara->method(), $compara->division(), $compara->dbname()],
	-CALLBACK => sub {
	  my ($sth, $dbh, $rv) = @_;
	  $compara->dbID($dbh->{mysql_insertid});
	});
  for my $genome (@{$compara->genomes()}) {
	$self->store($genome);
	$self->{dbc}->sql_helper()->execute_update(
	  -SQL =>
q/insert into genome_compara_analysis(genome_id,compara_analysis_id)
		values(?,?)/,
	  -PARAMS => [$genome->dbID(), $compara->dbID()]);
  }
  return;
}

sub _store_aliases {
  my ($self, $genome) = @_;
  for my $alias (@{$genome->aliases()}) {
	$self->{dbc}->sql_helper()->execute_update(
	  -SQL => q/insert into genome_alias(genome_id,alias)
		values(?,?)/,
	  -PARAMS => [$genome->dbID(), $alias]);
  }
  return;
}

sub _store_sequences {
  my ($self, $genome) = @_;
  my $it = natatime 1000, @{$genome->sequences()};
  while (my @vals = $it->()) {
	$self->{dbc}->sql_helper()
	  ->execute_update(-SQL =>
			 'insert into genome_sequence(genome_id,seq_name) values ' .
			 join(',', map { '('.$genome->dbID() . ',"' . $_ . '")' } @vals)
			 );
  }
  return;
}

sub _store_features {
  my ($self, $genome) = @_;
  while (my ($type, $f) = each %{$genome->features()}) {
	while (my ($analysis, $count) = each %$f) {
	  $self->{dbc}->sql_helper()->execute_update(
		-SQL =>
		  q/insert into genome_feature(genome_id,type,analysis,count)
		values(?,?,?,?)/,
		-PARAMS => [$genome->dbID(), $type, $analysis, $count]);
	}
  }
  return;
}

sub _store_annotations {
  my ($self, $genome) = @_;
  while (my ($type, $count) = each %{$genome->annotations()}) {
	$self->{dbc}->sql_helper()->execute_update(
	  -SQL => q/insert into genome_annotation(genome_id,type,count)
		values(?,?,?)/,
	  -PARAMS => [$genome->dbID(), $type, $count]);
  }
  return;
}

sub _store_variations {
  my ($self, $genome) = @_;
  while (my ($type, $f) = each %{$genome->variations()}) {
	while (my ($key, $count) = each %$f) {
	  $self->{dbc}->sql_helper()->execute_update(
		-SQL =>
		  q/insert into genome_variation(genome_id,type,name,count)
		values(?,?,?,?)/,
		-PARAMS => [$genome->dbID(), $type, $key, $count]);
	}
  }
  return;
}

sub _store_alignments {
  my ($self, $genome) = @_;
  while (my ($type, $f) = each %{$genome->other_alignments()}) {
	while (my ($key, $count) = each %$f) {
	  $self->{dbc}->sql_helper()->execute_update(
		-SQL =>
		  q/insert into genome_alignment(genome_id,type,name,count)
		values(?,?,?,?)/,
		-PARAMS => [$genome->dbID(), $type, $key, $count]);
	}
  }
  return;
}

sub fetch_all {
  my ($self, $keen) = @_;
  return $self->_generic_fetch_with_args({}, $keen);
}

sub fetch_by_dbID {
  my ($self, $id, $keen) = @_;
  return
	_first_element($self->_generic_fetch_with_args({'genome_id', $id}),
				   $keen);
}

sub fetch_by_assembly_id {
  my ($self, $id, $keen) = @_;
  return
	_first_element($self->_generic_fetch_with_args({'assembly_id', $id}
				   ),
				   $keen);
}

sub fetch_by_division {
  my ($self, $division, $keen) = @_;
  return $self->_generic_fetch_with_args({'division', $division},
										 $keen);
}

sub fetch_by_species {
  my ($self, $species, $keen) = @_;
  return
	_first_element($self->_generic_fetch_with_args({'species', $species}
				   ),
				   $keen);
}

sub fetch_variations {
  my ($self, $genome) = @_;
  croak
"Cannot fetch variations for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $variations = {};
  $self->{dbc}->sql_helper()->execute_no_return(
	-SQL =>
	  'select type,name,count from genome_variation where genome_id=?',
	-CALLBACK => sub {
	  my @row = @{shift @_};
	  $variations->{$row[0]}->{$row[1]} = $row[2];
	  return;
	},
	-PARAMS => [$genome->dbID()]);
  $genome->variations($variations);
  $genome->has_variations();
  return;
}

sub fetch_other_alignments {
  my ($self, $genome) = @_;
  croak
"Cannot fetch alignments for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $alignments = {};
  $self->{dbc}->sql_helper()->execute_no_return(
	-SQL =>
	  'select type,name,count from genome_alignment where genome_id=?',
	-CALLBACK => sub {
	  my @row = @{shift @_};
	  $alignments->{$row[0]}->{$row[1]} = $row[2];
	  return;
	},
	-PARAMS => [$genome->dbID()]);
  $genome->other_alignments($alignments);
  $genome->has_other_alignments();
  return;
}

sub fetch_annotations {
  my ($self, $genome) = @_;
  croak
"Cannot fetch annotations for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $annotations = {};
  $self->{dbc}->sql_helper()->execute_no_return(
	-SQL =>
	  'select type,count from genome_annotation where genome_id=?',
	-CALLBACK => sub {
	  my @row = @{shift @_};
	  $annotations->{$row[0]} = $row[2];
	  return;
	},
	-PARAMS => [$genome->dbID()]);
  $genome->annotations($annotations);
  return;
}

sub fetch_features {
  my ($self, $genome) = @_;
  croak
"Cannot fetch features  for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $features = {};
  $self->{dbc}->sql_helper()->execute_no_return(
	-SQL =>
'select type,analysis,count from genome_feature where genome_id=?',
	-CALLBACK => sub {
	  my @row = @{shift @_};
	  $features->{$row[0]}->{$row[1]} = $row[2];
	  return;
	},
	-PARAMS => [$genome->dbID()]);
  $genome->features($features);
  return;
}

sub fetch_publications {
  my ($self, $genome) = @_;
  croak
"Cannot fetch publications for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $pubs =
	$self->{dbc}->sql_helper()->execute_simple(
	   -SQL =>
		 'select publication from genome_publication where genome_id=?',
	   -PARAMS => [$genome->dbID()]);
  $genome->publications($pubs);
  return;
}

sub fetch_aliases {
  my ($self, $genome) = @_;
  croak
"Cannot fetch aliases for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $aliases =
	$self->{dbc}->sql_helper()->execute_simple(
			 -SQL => 'select alias from genome_alias where genome_id=?',
			 -PARAMS => [$genome->dbID()]);
  $genome->aliases($aliases);
  return;
}

sub fetch_sequences {
  my ($self, $genome) = @_;
  croak
"Cannot fetch sequences for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $sequences =
	$self->{dbc}->sql_helper()->execute_simple(
	   -SQL => 'select seq_name from genome_sequence where genome_id=?',
	   -PARAMS => [$genome->dbID()]);
  $genome->sequences($sequences);
  return;
}

sub fetch_comparas {
  my ($self, $genome) = @_;
  my $comparas = [];
  for my $id (
	@{$self->{dbc}->sql_helper()->execute_simple(
		-SQL =>
		  q/select distinct compara_analysis_id from compara_analysis 
  join genome_compara_analysis using (compara_analysis_id)
  where genome_id=? and method in ('BLASTZ_NET','LASTZ_NET','TRANSLATED_BLAT_NET', 'PROTEIN_TREES')/,
		-PARAMS => [$genome->dbID()])})
  {
	push @$comparas, $self->_fetch_compara($id);
  }
  $genome->compara($comparas);
  $genome->has_pan_compara();
  $genome->has_genome_alignments();
  $genome->has_peptide_compara();
  return;
}

sub _fetch_compara {
  my ($self, $id) = @_;
  # check to see if we've cached this already
  my $compara =
	$self->_get_cached_obj(
					 'Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo',
					 $id);
  if (!defined $compara) {
	# generate from a query
	# build the main object first
	($compara) = @{
	  $self->{dbc}->sql_helper()->execute(
		-SQL =>
q/select compara_analysis_id, division, method, dbname from compara_analysis where compara_analysis_id=?/,
		-PARAMS   => [$id],
		-CALLBACK => sub {
		  my @row = @{shift @_};
		  my $c =
			Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo->new();
		  $c->dbID($row[0]);
		  $c->division($row[1]);
		  $c->method($row[2]);
		  $c->dbname($row[3]);
		  return $c;
		});
	};
	$compara->adaptor($self);
# add genomes on one by one (don't nest the fetch here as could run of connections)
	my $genomes = [];
	for my $genome_id (
	  @{$self->{dbc}->sql_helper()->execute_simple(
		  -SQL =>
q/select distinct(genome_id) from genome_compara_analysis where compara_analysis_id=?/,
		  -PARAMS => [$id]);
	  })
	{
	  push @$genomes, $self->fetch_by_dbID($genome_id);
	}
	$compara->genomes($genomes);
	# cache the completed compara object
	$self->_store_cached_obj(
					 'Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo',
					 $compara);
  } ## end if (!defined $compara)
  return $compara;
} ## end sub _fetch_compara

sub _fetch_children {
  my ($self, $md) = @_;
  $self->fetch_variations($md);
  $self->fetch_sequences($md);
  $self->fetch_aliases($md);
  $self->fetch_publications($md);
  $self->fetch_annotations($md);
  $self->fetch_other_alignments($md);
  $self->fetch_comparas($md);
  return;
}

sub _first_element {
  my ($arr) = @_;
  if (defined $arr && scalar(@$arr) > 0) {
	return $arr->[0];
  }
  else {
	return undef;
  }
}

my $base_fetch_sql = q/
select 
genome_id as dbID,species,name,strain,serotype,division,taxonomy_id,
assembly_id,assembly_name,assembly_level,base_count,
genebuild,dbname,species_id,
has_pan_compara,has_variation,has_peptide_compara,
has_genome_alignments,has_other_alignments
from genome
/;

sub _generic_fetch_with_args {
  my ($self, $args, $keen) = @_;
  my $sql    = $base_fetch_sql;
  my $params = [values %$args];
  my $clause = join(',', map { $_ . '=?' } keys %$args);
  if ($clause ne '') {
	$sql .= ' where ' . $clause;
  }
  return $self->_generic_fetch($sql, $params, $keen);
}

sub _generic_fetch {
  my ($self, $sql, $params, $keen) = @_;
  my $mds = $self->{dbc}->sql_helper()->execute(
	-SQL          => $sql,
	-USE_HASHREFS => 1,
	-CALLBACK     => sub {
	  my $row = shift @_;
	  my $md =
		$self->_get_cached_obj(
							'Bio::EnsEMBL::Utils::MetaData::GenomeInfo',
							$row->{dbID});
	  if (!defined $md) {
		$md = bless $row, 'Bio::EnsEMBL::Utils::MetaData::GenomeInfo';
		$md->adaptor($self);
		$self->_store_cached_obj(
							'Bio::EnsEMBL::Utils::MetaData::GenomeInfo',
							$md);
	  }
	  return $md;
	},
	-PARAMS => $params);
  if (defined $keen && $keen == 1) {
	for my $md (@{$mds}) {
	  $self->_fetch_children($md);
	}
  }
  return $mds;
} ## end sub _generic_fetch

1;
