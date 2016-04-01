# ensembl-metadata
An API for storing and querying metadata about Ensembl and Ensembl Genomes releases. It can be used to find information about current and historic data releases, and also to retrieve DBAdaptor objects for use with the Ensembl Perl API without needing to use the Registry.

# Installation
This API requires the following Ensembl APIs (including their Perl dependencies):
- [ensembl](https://github.com/Ensembl/ensembl)
- [ensembl-taxonomy](https://github.com/Ensembl/ensembl-taxonomy)
- [ensembl-hive](https://github.com/Ensembl/ensembl-hive) (only if load pipelines are used)

In addition, additional Perl modules are required, listed in [the cpan dependency file](cpanfile).

# Usage

Full Perl documentation can be found at .... Some usage examples are shown below.

## Basic usage
```
via registry
```

```
direct instantiation
```

```
basic searches
```

```
working with taxonomy adaptor
```

## Working with releases
```
finding a release
```

```
setting a release
```

## Instantiating DBAdaptors

```
lookup example
```

# Implementation
## API object model
The `ensembl-metadata` API follows the same conventions as the core Ensembl APIs, with data objects stored and retrieved in the database via adaptors. For each of the following objects, there is a corresponding adaptor e.g. GenomeInfo is handled by GenomeInfoAdaptor. The adaptor is responsible for storing/updating objects, and for fetching them from the database.

### GenomeInfo
The central object in the implementation is GenomeInfo, which represents a specific version of a _genome_ from a specific release. Besides attributes such as annotation, genebuild etc., it also encapsulates an AssemblyInfo object.

### AssemblyInfo
This represents a particular assembly of a genome, and is independent of data releases. It encapsulates an OrganismInfo object. It also provides access to a list of top-level sequence.

### OrganismInfo
This represents a particular organism (regardless of taxonomic rank), and is independent of a data release. 

### GenomeComparaInfo
This object associates sets of GenomeInfo objects with a particular comparative genomics analysis (gene trees, whole genome alignments etc.)

### DataRelease
This represents a specific version of Ensembl or Ensembl Genomes, and is associated with sets of GenomeInfo objects, and also with DatabaseInfo objects for databases that aren't tied to any particular genome or compara (marts etc.)

### EventInfo
This represents an event that has happened to a piece of data, and can be attached to . This currently has a type, a source, a subject (i.e. an instance of GenomeInfo)

## Data schema
The following diagram shows the MySQL schema used by `ensembl-metadata`. The colour scheme indicates:
- blue = release-specific genome data
- pink = organism and assembly data (release dependent)
- red = comparative genomics data
- yellow = release information (database names, data releases)
- green = event history

<a href="sql/table.png"><img src="sql/table.png" alt="Schema diagram" style="width: 100%;"/></a>
