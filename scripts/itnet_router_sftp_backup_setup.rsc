# RouterOS 6.49+ / 7: configure these values before importing this installer.
# The shared SFTP account must have an existing directory for this identity.
{
    :local sftpHost "172.16.241.2"
    :local sftpPort 2022
    :local sftpUser "itnet-router-backup"
    :local sftpPassword "REPLACE_WITH_SHARED_SFTP_PASSWORD"
    :local remoteBase ""
    :local runImmediately true
    :local workerName "iTNet-Router-SFTP-Backup"
    :local settingsName "iTNet-Router-SFTP-Settings"
    :local jobPolicy "ftp,read,write,policy,test,password,sensitive"

    :if (($sftpPassword = ("REPLACE_WITH_" . "SHARED_SFTP_PASSWORD")) || ([:len $sftpPassword] = 0)) do={
        :error "Set the shared SFTP password before importing"
    }
    :if (([:len $sftpHost] = 0) || ([:len $sftpUser] = 0) || ($sftpPort < 1) || ($sftpPort > 65535)) do={
        :error "Invalid SFTP settings"
    }
    :if ([:len [/system script job find where script=$workerName]] > 0) do={
        :error "A backup is running; retry installation when it has finished"
    }

    :local quote do={
        :local value [:tostr $1]
        :local result "\""
        :if ([:len $value] > 0) do={
            :for index from=0 to=([:len $value] - 1) do={
                :local character [:pick $value $index ($index + 1)]
                :if (($character = "\r") || ($character = "\n")) do={
                    :error "SFTP settings must not contain line breaks"
                }
                :if (($character = "\\") || ($character = "\"") || ($character = "\$")) do={
                    :set result ($result . "\\")
                }
                :set result ($result . $character)
            }
        }
        :return ($result . "\"")
    }
    :local settingsSource (":return {\"host\"=" . [$quote $sftpHost] . ";\"port\"=" . $sftpPort . ";\"user\"=" . [$quote $sftpUser] . ";\"password\"=" . [$quote $sftpPassword] . ";\"base\"=" . [$quote $remoteBase] . "}")
    :local settingsId [/system script find where name=$settingsName]
    :if ([:len $settingsId] = 0) do={
        :set settingsId [/system script add name=$settingsName policy=$jobPolicy source=$settingsSource]
    } else={
        /system script set $settingsId policy=$jobPolicy source=$settingsSource dont-require-permissions=no
    }

    :local workerId [/system script find where name=$workerName]
    :if ([:len $workerId] = 0) do={
        :set workerId [/system script add name=$workerName policy=$jobPolicy source=""]
    }
    /system script set $workerId policy=$jobPolicy dont-require-permissions=no source={
        :local workerName "iTNet-Router-SFTP-Backup"
        :local prefix "itnet-sftp-"
        :if ([:len [/system script job find where script=$workerName]] > 1) do={
            :error "Another iTNet SFTP backup is running"
        }

        # Delete only this job's staging files, including failed previous runs.
        :foreach fileId in=[/file find] do={
            :local fileName [/file get $fileId name]
            :if ($fileName ~ "^itnet-sftp-.*\\.(backup|rsc|umb)\$") do={
                /file remove $fileId
            }
        }

        :local loader [:parse [/system script get [find where name="iTNet-Router-SFTP-Settings"] source]]
        :local settings [$loader]
        :local identity [/system identity get name]
        :if (([:len $identity] = 0) || ($identity = ".") || ($identity = "..") || ($identity ~ "[^A-Za-z0-9._ -]")) do={
            :error "Identity must contain only letters, digits, spaces, dots, underscores or hyphens"
        }
        :local dateValue [/system clock get date]
        :local timeValue [/system clock get time]
        :local dateStamp ""
        :if (([:len $dateValue] = 10) && ([:pick $dateValue 4 5] = "-") && ([:pick $dateValue 7 8] = "-")) do={
            :set dateStamp ([:pick $dateValue 0 4] . [:pick $dateValue 5 7] . [:pick $dateValue 8 10])
        } else={
            :if (([:len $dateValue] != 11) || ([:pick $dateValue 3 4] != "/") || ([:pick $dateValue 6 7] != "/")) do={
                :error "Unsupported RouterOS date format"
            }
            :local months {"jan"="01";"feb"="02";"mar"="03";"apr"="04";"may"="05";"jun"="06";"jul"="07";"aug"="08";"sep"="09";"oct"="10";"nov"="11";"dec"="12"}
            :local monthNumber ($months->[:pick $dateValue 0 3])
            :if ([:len $monthNumber] != 2) do={ :error "Unsupported RouterOS month" }
            :set dateStamp ([:pick $dateValue 7 11] . $monthNumber . [:pick $dateValue 4 6])
        }
        :local timeStamp ([:pick $timeValue 0 2] . [:pick $timeValue 3 5] . [:pick $timeValue 6 8])
        :if (([:len $dateStamp] != 8) || ($dateStamp ~ "[^0-9]") || ([:len $timeStamp] != 6) || ($timeStamp ~ "[^0-9]")) do={
            :error "Invalid clock; no backup was created"
        }
        :local baseName ($prefix . $identity . "-" . $dateStamp . "-" . $timeStamp)
        :local remoteDirectory (($settings->"base") . "/" . $identity . "/")
        :local version [/system resource get version]
        :local version6 ([:pick $version 0 2] = "6.")
        :local files {($baseName . ".backup");($baseName . ".rsc")}

        /system backup save name=$baseName dont-encrypt=yes
        :local exportCommand ("/export verbose file=\"" . $baseName . "\" ")
        :if (!$version6) do={
            :set exportCommand ($exportCommand . "show-sensitive")
        }
        :local exporter [:parse $exportCommand]
        $exporter

        # User Manager is not part of a native RouterOS configuration backup.
        :if ([:len [/system package find where name="user-manager" disabled=no]] > 0) do={
            :local umCommand ("/user-manager database save name=\"" . $baseName . ".umb\"")
            :if ($version6) do={
                :set umCommand ("/tool user-manager database save name=\"" . $baseName . ".umb\"")
            }
            :local saveUserManager [:parse $umCommand]
            $saveUserManager
            :set files ($files,($baseName . ".umb"))
        }

        :local allUploaded true
        :foreach fileName in=$files do={
            :local fileId [/file find where name=$fileName]
            :if ([:len $fileId] = 0) do={ :error ("Backup file is missing: " . $fileName) }
            :if ([/file get $fileId size] = 0) do={ :error ("Backup file is empty: " . $fileName) }
            :local uploaded false
            :for attempt from=1 to=3 do={
                :if (!$uploaded) do={
                    :do {
                        :local result [/tool fetch url=("sftp://" . ($settings->"host") . ":" . ($settings->"port") . $remoteDirectory . $fileName) port=($settings->"port") user=($settings->"user") password=($settings->"password") src-path=$fileName dst-path=($remoteDirectory . $fileName) upload=yes keep-result=no duration=5m as-value]
                        :if (($result->"status") != "finished") do={ :error "SFTP upload did not finish" }
                        /file remove [find where name=$fileName]
                        :set uploaded true
                    } on-error={
                        :log warning ("iTNet SFTP backup: attempt " . $attempt . " failed for " . $fileName)
                        :if ($attempt < 3) do={ :delay 15s }
                    }
                }
            }
            :if (!$uploaded) do={
                :set allUploaded false
                :log error ("iTNet SFTP backup: upload or local cleanup failed for " . $fileName)
            }
        }
        :if (!$allUploaded) do={
            :error "iTNet SFTP backup incomplete; remaining staging files will be removed next run"
        }
        :log info ("iTNet SFTP backup complete: " . $identity . " " . $dateStamp . "-" . $timeStamp)
        :put "ITNET_BACKUP_COMPLETE"
    }

    :local schedulerId [/system scheduler find where name=$workerName]
    :if ([:len $schedulerId] = 0) do={
        /system scheduler add name=$workerName on-event=$workerName policy=$jobPolicy interval=1d start-date=[/system clock get date] start-time=08:00:00 disabled=no
    } else={
        /system scheduler set $schedulerId on-event=$workerName policy=$jobPolicy interval=1d start-date=[/system clock get date] start-time=08:00:00 disabled=no
    }
    /system scheduler disable [find where name="Backup to ftp"]
    :if ([/system clock get time-zone-name] != "Asia/Tehran") do={
        :log warning "iTNet backup runs at 08:00 router local time; verify the Tehran timezone policy"
    }
    :put "ITNET_BACKUP_INSTALLED"
    :if ($runImmediately) do={ /system script run $workerName }
}
