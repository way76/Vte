<?php
/**
 * PHP mysqldump CLI
 * 
 */

// PARAMETRI DI CONFIGURAZIONE
// accesso a MySQL
$dbuser = "c0logika_vte";
$dbpass = "KNp@Hb76c";
$db = "information_schema"; // c0logika_vte

// accesso FTP a server
$ftpUser = "root";
$ftpPass = "BQcLeE7UWa3jn";
$pathToUpload = "/var/www/wootest/backup/";
$sftp = "sftp://$ftpUser:$ftpPass@167.86.74.74$pathToUpload";

// cartella locale per archiviazione, cartella temporanea di lavoro e dimensione split archivio tar
$backupDir = "/var/www/html/logika/backup_test";
$sitewebDir = "/var/www/html/logika/web/themes";
$tempBackupDir ="/var/www/html/logika/temp_backup";
$backupDbFilename = "db-" . date("Ymd") . ".sql.gz";
$backupSitewebFilename = "sw-" . date("Ymd") . ".gz";
$nomeFileTar = "backup-" . date("Ymd") . ".tar.gz";
$stdOutputDb = $tempBackupDir.'/'.$backupDbFilename;
$stdOutputSitoweb = $tempBackupDir.'/'.$backupSitewebFilename;
$stdOutputFileTar = $tempBackupDir.'/'.$nomeFileTar;
$stdOutputSplitTar = $backupDir.'/'.$nomeFileTar;

$mimeType = "application/x-gzip";
$splitDimension = "5M";
$remoteUrl = "http://wootest.logikadev.it/wootest/backup/";

// path a comando mysql
$mysqldump = "/usr/bin/mysqldump";

if (!defined('STDIN')) {
    // Blocco se si accede da browser
    die('Accesso negato!');

} else {

    print "********* SCRIPT PHP START...\n\n";
    print "-- Eseguo MySQL DUMP\n";

    // dump database mysql e compressione
    // NOTA
    // bisogna configurare la password su  
    // cd /etc/mysql/conf.d/mysqldump.cnf
    // aggiungere password = la-password-per-mysql
    exec("$mysqldump -u $dbuser $db --single-transaction --quick --routines --triggers --events --no-tablespaces | gzip -7 > $stdOutputDb");
    print "----> MySQl DUMP fatto!\n\n";

    // backup e compressione sito web vte
    print "-- Eseguo backup dati sito web\n";
    $backupSitoweb = "tar cvzf $stdOutputSitoweb $sitewebDir --absolute-names --exclude=vte_updater --exclude --exclude=backup";
    exec("$backupSitoweb");
    print "----> Backup sito web fatto!\n\n";
    
    // compatto i due file in uno
    print "-- Eseguo compattazione finale database e sito web\n";
    $compattazioneArchivi = "tar cvzf $stdOutputFileTar $stdOutputDb $stdOutputSitoweb --absolute-names";
    exec("$compattazioneArchivi");
    print "----> Compattazione effettuata!\n\n";

    // split archivio tar
    print "-- Eseguo SPLIT archivio tar\n";
    $splitArchivioTar = "tar cvzf - $stdOutputFileTar --absolute-names | split -b $splitDimension - $stdOutputSplitTar.";
    exec("$splitArchivioTar");
    print "----> SPLIT archivio tar fatto!\n\n";

    // upload verso server remoto della cartella upload
    print "-- Trasferimento files al server remoto\n";
    // ciclo nella directory backup...
    if ($handle = opendir($backupDir)) {
        while (false !== ($entry = readdir($handle))) {
            if ($entry != "." && $entry != "..") {

                print "-- Upload di $entry\n";

                // exec("curl -T $entry -k $sftp");
                exec("curl -k $sftp -T $backupDir/$entry");

                $file_headers = @get_headers($remoteUrl.$entry);
                if($file_headers[0] == 'HTTP/1.1 404 Not Found') {
                print "----> Upload di $entry su server remoto non riuscito\n\n";
                }
                else {
                    print "----> Upload di $entry fatto!\n\n";
                }
            }
        }    
        closedir($handle);
    }

    // eliminazione del file di backup originale
    /* print "-- Eliminazione copia di backup locale: \n\n";

    if (!unlink($stdOutputSitoweb)) { 
        echo ("----> Impossibile eliminare la copia del sito web\n\n"); 
    } else { 
        echo ("----> Copia del sito web eliminata\n\n"); 
    } 

    if (!unlink($stdOutputFileTar)) { 
        echo ("----> Impossibile eliminare la copia del file tar\n\n"); 
    } else { 
        echo ("----> Copia del file tar eliminata\n\n"); 
    } 

    if (!unlink($stdOutputDb)) { 
        echo ("----> Impossibile eliminare la copia del database\n\n"); 
    } else { 
        echo ("----> Copia del database eliminata\n\n"); 
    } */ 

    // elimina copia in directory upload
    /* if ($handle = opendir($backupDir)) {
        while (false !== ($entry = readdir($handle))) {
            if ($entry != "." && $entry != "..") {
                if (!unlink($backupDir.'/'.$entry)) { 
                    print "----> Impossibile eliminare $entry\n\n";
                }
                else {
                    print "----> $entry eliminato!\n\n";
                }
            }
        }    
        closedir($handle);
    } */   

    print "********* SCRIPT PHP END\n";

}

exit;
