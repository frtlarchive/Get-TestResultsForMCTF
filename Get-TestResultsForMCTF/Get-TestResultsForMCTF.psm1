using namespace System.Collections.Generic
#where $FreightItems is a collection of FreightItems, #Tests is a collection
# of regex tests for fields in those FreightItems and CompanyTypeMappings
# holds mappings for FreightItems fields to unique combinations for companytypes
function Get-TestResultsForMCTF($FreightItems,$Tests,$CompanyTypeMappings){
    #get freight only test results
    $FreightOnlyTR = foreach ($t in $Tests) {
        if ($t.type -eq "Freight") {
            foreach ($f in $FreightItems) {
                if ($f.$($t.field) -NotMatch $t.test) {
                    [pscustomobject]@{
                        ord_hdrnumber = $f.ord_hdrnumber
                        fgt_number    = $f.fgt_number
                        test          = $t.name
                        current       = $_.$($t.field)
                    }
                }
            }
        }
    }
    if($null -eq $FreightOnlyTR){$FreightOnlyTR = @()}
    #get company only test results
    $CompanyTR = foreach ($ctm in $CompanyTypeMappings) {
        $companies = $FreightItems |
            Where-Object $ctm.k -match ".+" |
            Group-Object $ctm.f |
            ForEach-Object { $_.Group[0] | Select-Object $ctm.f }
        $tt = $Tests |
            Where-Object Type -eq $ctm.t
        foreach ($c in $companies) {
            foreach ($t in $tt) {
                if ($c.$($t.field) -NotMatch $t.test) {
                    [pscustomobject]@{
                        type    = $t.type
                        cmp_id  = $c.$($ctm.k)
                        test    = $t.name
                        current = $c.$($t.field)
                    }
                }                
            }
        }
    }
    if($null -eq $CompanyTR){$CompanyTR = @()}
    #convert the company results to a single record formatted like the freight errors
    $BadCompanyTRF = foreach ($ctm in $CompanyTypeMappings) {
        $CompanyTRGroups = $CompanyTR | Where-Object Type -eq $ctm.t | Group-Object Type
        foreach ($c in $CompanyTRGroups) {
            $badids = [HashSet[string]]::new([string[]]($c.Group.cmp_id))
            foreach ($f in $FreightItems) {
                if ($badids.Contains($f.$($ctm.k))) {
                    [PSCustomObject]@{
                        ord_hdrnumber = $f.ord_hdrnumber
                        fgt_number    = $f.fgt_number
                        test          = "Bad {0} Record" -f $ctm.t
                        current       = $f.$($ctm.k)
                    }
                }
            }
        }
    }
    if($null -eq $BadCompanyTRF){$BadCompanyTRF = @()}

    #return company errors and combined errors formatted for freight.
    $CompanyTR,($FreightOnlyTR + $BadCompanyTRF)
}
Export-ModuleMember -Function * -Alias *