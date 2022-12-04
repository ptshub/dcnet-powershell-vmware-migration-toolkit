$webrequest=[net.webrequest]::Create("https://10.1.1.110:5392")
try { $webrequest.getresponse() } catch {}
$cert=$webrequest.servicepoint.certificate
$bytes=$cert.export([security.cryptography.x509certificates.x509contenttype]::cert)
$tfile=[system.io.path]::getTempFileName()
set-content -value $bytes -encoding byte -path $tfile
import-certificate -filepath $tfile -certStoreLocation 'Cert:\CurrentUser\Root'
import-certificate -filepath $tfile -certStoreLocation 'Cert:\localmachine\Root'