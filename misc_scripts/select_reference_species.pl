#!/usr/bin/env perl
# Copyright [2009-2014] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


=head1 NAME

select_reference_species.pl - This script picks a reference to use for compara from multiple strains of a given species

=head1 SYNOPSIS

select_reference_species.pl [arguments]

  --user=user                         username for the core database

  --pass=pass                         password for core database

  --host=host                         server where the core databases are stored

  --port=port                         port for core database

  --pattern=pattern                   core databases to examine
                                      Note that this is a standard regular expression of the
                                      form '^[a-b].*core.*' for all core databases starting with a or b

  --dbname=dbname                     single core database to process
  
    --division                        division to restrict to
 
  --help                              print help (this message)

=head1 DESCRIPTION



=head1 EXAMPLES


=head1 MAINTAINER

Dan Staines <dstaines@ebi.ac.uk>, Ensembl Genomes

=head1 AUTHOR

$Author$

=head1 VERSION

$Revision$

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 


=cut

use warnings;
use strict;

use Carp;
use Log::Log4perl qw(:easy);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::CliHelper;
use Pod::Usage;

use File::Path qw( make_path );

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();

my $optsd = $cli_helper->get_dba_opts();

push(@{$optsd}, "division:s");
push(@{$optsd}, "reference_taxids:s");
# process the command line with the supplied options plus a help subroutine
my $opts = $cli_helper->process_args($optsd, \&pod2usage);
if ($opts->{verbose}) {
  Log::Log4perl->easy_init($DEBUG);
} else {
  Log::Log4perl->easy_init($INFO);
}

my $logger = get_logger();

my $refs = {};
croak "No reference taxid file supplied" unless defined $opts->{reference_taxids};
open my $ref_file, "<", $opts->{reference_taxids} || croak "Could not open file ".$opts->{reference_taxids};
while(<$ref_file>) {
    chomp;
    $refs->{$_} = 1;
}
close $ref_file;

my $species_dbas = {};
my $n=0;

for my $db_args (@{$cli_helper->get_dba_args_for_opts($opts)}) {

  my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%{$db_args});
  my $meta = $dba->get_MetaContainer();

  if(!defined $opts->{division} || $opts->{division} eq $meta->get_division()) {
      my $species = $meta->single_value_by_key("species.production_name");
      if($species =~ m/cruzi/) {
      $logger->info("Processing ".$species. "(".$dba->dbc()->dbname()."/".$dba->species_id().")\n");
      my $species_id = $meta->single_value_by_key("species.species_taxonomy_id");
      croak "Species tax ID not set" unless defined $species_id;
      my $taxid = $meta->single_value_by_key("species.taxonomy_id");
      my $dba_details = {
          dba=>$dba,
          is_single=> ($dba->dbc()->dbname() =~ m/_collection_/)?0:1,
          genebuild=>$meta->single_value_by_key("genebuild.start_date"),
          species=>$species,
          is_species_level=>($meta->single_value_by_key("species.species_taxonomy_id") eq $taxid)?1:0,
          species_id=>$dba->species_id(),
          dbname=>$dba->dbc()->dbname(),
          is_ref=>($refs->{$taxid}||0)
      };
      push @{$species_dbas->{$species_id}}, $dba_details;
      $n++;
      }
  }

  $dba->dbc()->disconnect_if_idle();

}

$logger->info("Found $n genomes from ".scalar(keys %$species_dbas)." species");
while(my ($taxid,$dbas) = each %$species_dbas) {
    my @srt_dbas = sort {
        $b->{is_single} <=> $a->{is_single}  || 
            $b->{is_ref} <=> $a->{is_ref} || 
            $a->{genebuild} cmp $b->{genebuild} || 
            $a->{species_id} <=> $b->{species_id} || 
            $b->{is_species_level} eq $a->{is_species_level}
    } @$dbas;
    my $dba = $srt_dbas[0];
    print join("\t",$taxid,$dba->{species},$dba->{dbname},$dba->{species_id})."\n";
}
