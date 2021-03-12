#ifndef UPNPDROPLOG_H_INCLUDED
#define UPNPDROPLOG_H_INCLUDED

#include "sqlite3.h"

//Initializes database for dropped packets at path = <db_name>
int InitDropDB(const char *db_name);

//Loggs dropped packet
int LogDropDb(unsigned short eport, const char * iaddr, 
            unsigned short iport, const char * protocol);

//Gets new logged packet id
int GetNewIdDropDb();

//Closes dropped packets database
void CloseDropDB();

#endif