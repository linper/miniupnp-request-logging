
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <syslog.h>

#include "sqlite3.h"
#include "droplog.h"

static sqlite3 *db = NULL;
int _SetRowId(void* pNames, int argc, char** argv, char** col_names);

int InitDropDB(const char *db_path)
{
	int rc;
	char *err;
    if (db){
        syslog(LOG_ERR, "MINIUPNPD: dropped packets database already initialized");
        return -1;
    }
	//opens DB
	if ((rc = sqlite3_open(db_path, &db)) != SQLITE_OK)
		return -1;
	//creates table for dropped packets if it's not present
	char *sql = "CREATE TABLE IF NOT EXISTS packets(timestamp TEXT, id INT, \
                        eport INT, iaddr INT, iport INT, proto TEXT);";
	if ((rc = sqlite3_exec(db, sql, 0, 0, &err)) != SQLITE_OK){
        syslog(LOG_ERR, "MINIUPNPD: dropped packets' database initialization failed: %s", err);
		sqlite3_free(err);
		return -1;
	}
	return 0;
}

int LogDropDb(unsigned short eport, const char * iaddr, 
            unsigned short iport, const char * protocol)
{
	char buff[128];
	int rc;
	char *err;
	int id = 0;
	if (GetNewIdDropDb(&id) != 0)
		return -1;
	if ((rc = sprintf(buff, "INSERT INTO packets VALUES(datetime('now'), \
			'%u', '%hu', '%s', '%hu', '%s');", \
                        id , eport, iaddr, iport, protocol)) < 0){
		return -1;
						}

	if ((rc = sqlite3_exec(db, buff, 0, 0, &err)) != SQLITE_OK){
        syslog(LOG_ERR, "MINIUPNPD: dropped packets' database insert failed: %s", err);
		sqlite3_free(err);
		return -1;
	}
	return 0;
}

int _SetRowId(void* id, int argc, char** argv, char** col_names)
{
	if (argc == 1 && !argv[0]){
		*(int*)id = 0;
		return 0;
	}
	char str[10];
    long value;
    strcpy(str, argv[0]);
    value = strtol(str, &argv[0], 10);
	*(int*)id = (int)value + 1;
	return 0;
}

int GetNewIdDropDb(int *id)
{
	char *err;
	if (sqlite3_exec(db, "SELECT MAX(id) FROM packets;", _SetRowId, id, &err) != SQLITE_OK){
        syslog(LOG_ERR, "MINIUPNPD: dropped packets' database id search failed: %s", err);
		sqlite3_free(err);
		return -1;
	}
	return 0;
}

void CloseDropDB()
{
    sqlite3_close(db);
}