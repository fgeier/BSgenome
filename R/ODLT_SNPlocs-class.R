### =========================================================================
### ODLT_SNPlocs objects
### -------------------------------------------------------------------------


setClass("ODLT_SNPlocs",
    contains="SNPlocs",
    representation(
        snp_table="OnDiskLongTable"
    )
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Low-level constructor
###

new_ODLT_SNPlocs <- function(provider, provider_version,
                             release_date, release_name,
                             source_data_url, download_date,
                             reference_genome, compatible_genomes,
                             data_pkgname, data_dirpath)
{
    snp_table <- OnDiskLongTable(data_dirpath)
    new("ODLT_SNPlocs",
        provider=provider,
        provider_version=provider_version,
        release_date=release_date,
        release_name=release_name,
        source_data_url=source_data_url,
        download_date=download_date,
        reference_genome=reference_genome,
        compatible_genomes=compatible_genomes,
        data_pkgname=data_pkgname,
        snp_table=snp_table)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### snpcount()
###

setMethod("snpcount", "ODLT_SNPlocs",
    function(x)
    {
        spatial_index <- spatialIndex(x@snp_table)
        batch_seqnames <- seqnames(spatial_index)
        batches_per_seq <- runLength(batch_seqnames)
        batch_breakpoints <- breakpoints(x@snp_table)
        seq_breakpoints <- batch_breakpoints[cumsum(batches_per_seq)]
        setNames(S4Vectors:::diffWithInitialZero(seq_breakpoints),
                 runValue(batch_seqnames))
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### .as_GPos()
###

.as_GPos <- function(df, seqinfo, drop.rs.prefix=FALSE)
{
    ans_seqnames <- df[ , "seqnames"]
    ans_ranges <- IRanges(df[ , "pos"], width=1L)
    ans_strand <- Rle(factor("+", levels=levels(strand())), nrow(df))
    gr <- GRanges(ans_seqnames, ans_ranges, ans_strand, seqinfo=seqinfo)

    ans_alleles_as_ambig <- safeExplode(rawToChar(df[ , "alleles"]))
    rowids <- df$rowids
    if (is.null(rowids)) {
        ans_mcols <- DataFrame(alleles_as_ambig=ans_alleles_as_ambig)
    } else {
        if (!drop.rs.prefix && length(gr) != 0L)
            rowids <- paste0("rs", rowids)
        ans_mcols <- DataFrame(RefSNP_id=rowids,
                               alleles_as_ambig=ans_alleles_as_ambig)
    }
    mcols(gr) <- ans_mcols
    as(gr, "GPos")
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### SNP extractors: snpsBySeqname(), snpsByOverlaps(), snpsById()
###

.snpsBySeqname_ODLT_SNPlocs <- function(x, seqnames, drop.rs.prefix=FALSE)
{
    if (!isTRUEorFALSE(drop.rs.prefix))
        stop(wmsg("'drop.rs.prefix' must be TRUE or FALSE"))

    df <- getBatchesBySeqnameFromOnDiskLongTable(x@snp_table, seqnames,
                                                 with.rowids=TRUE)
    x_spatial_index <- spatialIndex(x@snp_table)
    x_seqinfo <- seqinfo(x_spatial_index)
    .as_GPos(df, x_seqinfo, drop.rs.prefix=drop.rs.prefix)
}

setMethod("snpsBySeqname", "ODLT_SNPlocs", .snpsBySeqname_ODLT_SNPlocs)

.snpsByOverlaps_ODLT_SNPlocs <- function(x, ranges,
                maxgap=0L, minoverlap=0L,
                type=c("any", "start", "end", "within", "equal"),
                drop.rs.prefix=FALSE, ...)
{
    ranges <- normarg_ranges(ranges)
    if (!isTRUEorFALSE(drop.rs.prefix))
        stop(wmsg("'drop.rs.prefix' must be TRUE or FALSE"))

    df <- getBatchesByOverlapsFromOnDiskLongTable(x@snp_table, ranges,
                                                  maxgap=maxgap,
                                                  minoverlap=minoverlap,
                                                  with.rowids=TRUE)
    x_spatial_index <- spatialIndex(x@snp_table)
    x_seqinfo <- seqinfo(x_spatial_index)
    gpos <- .as_GPos(df, x_seqinfo, drop.rs.prefix=drop.rs.prefix)
    subsetByOverlaps(gpos, ranges,
                     maxgap=maxgap, minoverlap=minoverlap,
                     type=type, ...)
}

setMethod("snpsByOverlaps", "ODLT_SNPlocs", .snpsByOverlaps_ODLT_SNPlocs)

.snpsById_ODLT_SNPlocs <- function(x, ids,
                                   ifnotfound=c("error", "warning", "drop"))
{
    user_rowids <- ids2rowids(ids)
    ifnotfound <- match.arg(ifnotfound)
    x_rowids <- rowids(x@snp_table)
    rowidx <- rowids2rowidx(user_rowids, ids, x_rowids, ifnotfound)

    df <- getRowsFromOnDiskLongTable(x@snp_table, rowidx[[1L]],
                                     with.rowids=FALSE)
    df$rowids <- rowidx[[2L]]
    x_spatial_index <- spatialIndex(x@snp_table)
    x_seqinfo <- seqinfo(x_spatial_index)
    .as_GPos(df, x_seqinfo, drop.rs.prefix=TRUE)
}

setMethod("snpsById", "ODLT_SNPlocs", .snpsById_ODLT_SNPlocs)
