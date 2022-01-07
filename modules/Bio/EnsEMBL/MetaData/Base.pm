
=head1 LICENSE

Copyright [1999-2022] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::Base

=head DESCRIPTION

Base class for shared method

=head1 AUTHOR

Thomas Maurel

=cut

use strict;
use warnings;

package Bio::EnsEMBL::MetaData::Base;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Exporter qw/import/;
our @EXPORT_OK = qw(get_division process_division_names fetch_and_set_release check_assembly_update check_genebuild_update);

=head2 get_division
  Description: Get division for a given database adaptor. If the database is a core like, get the core database
  Arg        : Database adaptor
  Returntype : String
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut
sub get_division {
  my ($dba) = @_;
  if ($dba->group eq 'core') {
    return $dba->get_MetaContainer->get_division();
  }
  else {
    my $core_dba = create_core_dba($dba);
    if ($core_dba->group eq 'core') {
      my $division = $core_dba->get_MetaContainer->get_division();
      $core_dba->dbc()->disconnect_if_idle();
      return $division;
    } else {
      $core_dba->dbc()->disconnect_if_idle();
      die "Could not retrieve Core database for ".$core_dba->dbc->dbname();
    }
  }
}

=head2 create_core_dba
  Description: Create a core dba from a core like database dba
  Arg        : Database adaptor
  Returntype : Core Database adaptor
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut
sub create_core_dba {
  my ($dba) = @_;
  my $core_dbname = $dba->dbc->dbname();
  $core_dbname =~ s/(_otherfeatures_|_rnaseq_|_cdna_|_variation_|_funcgen_)/_core_/;
  my $species = $dba->dbc()->sql_helper()->execute_simple( -SQL =>qq/select meta_value from meta where meta_key=?/, -PARAMS => ['species.production_name']);
  my $core_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -user   => $dba->dbc->user,
    -host   => $dba->dbc->host,
    -port   => $dba->dbc->port,
    -pass => $dba->dbc->pass,
    -dbname => $core_dbname,
    -species => $species,
    -group => 'core'
    );
  return $core_dba;
}

=head2 process_division_names
  Description: Process the division name, and return both division like metazoa and division name like EnsemblMetazoa
  Arg        : division name or division short name
  Returntype : string
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut
sub process_division_names {
  my ($div) = @_;
  my $division;
  my $division_name;
  #Creating the Division name EnsemblBla and division bla variables
  if ($div !~ m/[E|e]nsembl/){
    $division = $div;
    $division_name = 'Ensembl'.ucfirst($div) if defined $div;
  }
  else{
    $division_name = $div;
    $division = $div;
    $division =~ s/Ensembl//;
    $division = lc($division);
  }
  return ($division,$division_name)
}


=head2 fetch_and_set_release
  Description: fetch the right release for a release data Info adaptor and set it in the Genome Data Info Adaptor
  Arg        : release version
  Arg        : Release Data Info Adaptor
  Arg        : Genome Data Info Adaptor
  Returntype : adaptors and string
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut
sub fetch_and_set_release {
  my ($release_version,$rdba,$gdba) = @_;
  my ($release_info,$release);
  if (defined $release_version){
    $release_info = $rdba->fetch_by_ensembl_genomes_release($release_version);
    if (!$release_info){
      $release_info = $rdba->fetch_by_ensembl_release($release_version);
      $release = $release_info->{ensembl_version};
    }
    else{
      $release = $release_info->{ensembl_genomes_version};
    }
    $gdba->data_release($release_info);
  }
  else{
    $release_info = $rdba->fetch_current_ensembl_release();
    if (!$release_info){
      $release_info = $rdba->fetch_current_ensembl_genomes_release();
      $release = $release_info->{ensembl_genomes_version};
    }
    else{
      $release = $release_info->{ensembl_version};
    }
    $gdba->data_release($release_info);
  }
  return ($rdba,$gdba,$release,$release_info);
}

=head2 check_assembly_update
  Description: Compare assembly information between two genomes from different releases and check if the assembly has been updated.
  Arg        : Current release genome object
  Arg        : Previous release genome object
  Returntype : string
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut
sub check_assembly_update {
  my ($genome,$prev_genome) = @_;
  my $updated_assembly=0;
  # Check assembly default meta key
  $updated_assembly = 1 if $genome->assembly_default() ne $prev_genome->assembly_default();
  # Also check the assembly name meta key for patches update. Mainly affects human and mouse
  $updated_assembly = 2 if $genome->assembly_name() ne $prev_genome->assembly_name();
  # Check base_count value which is the sum of lenght of seq_region. If new sequences have been added to the assembly, this will change.
  # We can pick up new MT or scaffolds
  $updated_assembly = 3 if $genome->base_count() ne $prev_genome->base_count();
  return $updated_assembly;
}


=head2 check_genebuild_update
  Description: Compare genebuild information between two genomes from different releases and check if the gene set has been updated.
  Arg        : Current release genome object
  Arg        : Previous release genome object
  Returntype : string
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut
sub check_genebuild_update {
  my ($genome,$prev_genome) = @_;
  my $updated_genebuild = 0;
  $updated_genebuild = 1 if $genome->genebuild() ne $prev_genome->genebuild();
  return $updated_genebuild;
}

1;