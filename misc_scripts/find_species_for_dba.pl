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

find_species_for_dba.pl - This script finds the species level taxon to which the annotated taxonomy node for the database belones

=head1 SYNOPSIS

find_species_for_dba.pl [arguments]

  --user=user                         username for the core database

  --pass=pass                         password for core database

  --host=host                         server where the core databases are stored

  --port=port                         port for core database

  --pattern=pattern                   core databases to examine
                                      Note that this is a standard regular expression of the
                                      form '^[a-b].*core.*' for all core databases starting with a or b

  --dbname=dbname                     single core database to process
  
  --taxuser=user                         username for the taxonomy database

  --taxpass=pass                         password for taxonomy database

  --taxhost=host                         server where the taxonomy databases are stored

  --taxport=port                         port for taxonomy database

  --taxdbname=dbname                     taxonomy database
                                      
  --species_id=species_id			  ID of species to run over (by default all species in database are examined)
  
  --write_meta                        if specified, write the species name to a meta key

  --help                              print help (this message)

=head1 DESCRIPTION

This script tries to find the species name for each genome, and store the URL to the wikipedia page if it exists

=head1 EXAMPLES

perl -I modules/ misc-scripts/find_species_for_dba.pl \
  -host mysql-eg-staging-2 -port 4275 -user ensrw -pass xyz -dbname bacteria_1_collection_core_20_73_1 \
  -taxuser ensro -taxhost mysql-eg-staging-2 -taxport 4275 -taxdbname ncbi_taxonomy -write_meta

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
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;
use Bio::EnsEMBL::Utils::CliHelper;
use Pod::Usage;
use URI::Escape;
use LWP::UserAgent;
use List::MoreUtils qw(uniq);

use File::Path qw( make_path );

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();

my $optsd = [@{$cli_helper->get_dba_opts()}, @{$cli_helper->get_dba_opts('tax')}];

push(@{$optsd}, "write_meta");
push(@{$optsd}, "division:s");
push(@{$optsd}, "outfile:s");

# process the command line with the supplied options plus a help subroutine
my $opts = $cli_helper->process_args($optsd, \&pod2usage);
if ($opts->{verbose}) {
  Log::Log4perl->easy_init($DEBUG);
} else {
  Log::Log4perl->easy_init($INFO);
}
my $logger = get_logger();

$opts->{outfile} ||= "./species.txt";

my $wiki_url_base = "http://en.wikipedia.org/wiki/";
my $meta_key      = "species.wikipedia_url";
my ($tax_dba_details) = @{$cli_helper->get_dba_args_for_opts($opts, 1, 'tax')};
my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new(Bio::EnsEMBL::DBSQL::DBAdaptor->new(%{$tax_dba_details}));

$logger->info("Writing report file to " . $opts->{outfile});
open my $outfile, ">", $opts->{outfile} || croak "Could not open " . $opts->{outfile} . " for writing";

my $wiki_urls = {};

my $ua = LWP::UserAgent->new();

## use the command line options to get an array of database details
for my $db_args (@{$cli_helper->get_dba_args_for_opts($opts)}) {

  # use the args to create a DBA
  my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%{$db_args});

  my $meta = $dba->get_MetaContainer();
  if (defined $opts->{division} && $meta->get_division() ne $opts->{division}) {
	$dba->dbc()->disconnect_if_idle(1);
	next;
  }

  my $dbname = $dba->dbc()->dbname();
  #my $nom = $dba->dbc()->dbname() . '.' . $dba->species_id();
  my $nom = $dbname . '.' . $dba->species_id() . (defined $dba->species() ? ' (' . $dba->species() . ')' : '');
  $logger->info("Analysing $nom\n");

  my $taxid = $meta->get_taxonomy_id();

  if (!defined $taxid) {
	croak "Taxonomy ID not set for $nom";
  }

  my $node = $node_adaptor->fetch_by_taxon_id($taxid);
  if (!defined $node) {
	carp "Taxonomy ID $taxid not found in taxonomy database for $nom";
	$dba->dbc()->disconnect_if_idle(1);
	next;
  }

  my $species = $node_adaptor->fetch_ancestor_by_rank($node, "species");

  if (!defined $species) {
	carp "Species not found for taxon node $taxid for $nom";
  } else {
	$logger->info("Found species " . $species->name());
	print $outfile $dbname . "\t" . $dba->species_id() . "\t" . $dba->species() . "\t" . $species->name() . "\n";

	if ($opts->{write_meta}) {
	  my $wiki_url = $wiki_urls->{$species->name()};
	  if (!$wiki_url) {
		($wiki_url = $wiki_url_base . $species->name()) =~ s/ +/_/g;
		if (!$ua->get($wiki_url)->is_success) {
		  $wiki_url = 'MISSING';
		}
		$wiki_urls->{$species->name()} = $wiki_url;
	  }

	  if ($wiki_url ne 'MISSING') {
		my $curr_wiki_url = $meta->single_value_by_key($meta_key);
		if (!defined $curr_wiki_url || $curr_wiki_url ne $wiki_url) {
		  $logger->info("Inserting meta key $meta_key $wiki_url");
		  $meta->store_key_value($meta_key, $wiki_url);
		}
	  }
	}

  }

  $dba->dbc()->disconnect_if_idle(1);

} ## end for my $db_args (@{$cli_helper...})

close $outfile;
