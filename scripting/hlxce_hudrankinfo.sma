/*
*	HLXCE HUDRankInfo		     v. 0.1.1
*	by serfreeman1337	http://gf.hldm.org/
*/

#include <amxmodx>
#include <csx>
#include <engine>
#include <sqlx>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	
	#define print_team_default DontChange
	#define print_team_grey Grey
	#define print_team_red Red
	#define print_team_blue Blue
#endif

#define PLUGIN "HLXCE HUDRankInfo"
#define VERSION "0.1.1 Beta"
#define AUTHOR "serfreeman1337"

#define HUD_INFORMER_OFFSET	6132

enum _:cvars {
	CVAR_HLXCE_HOST,
	CVAR_HLXCE_USER,
	CVAR_HLXCE_PASSWORD,
	CVAR_HLXCE_DB,
	CVAR_HLXCE_GAME,
	
	CVAR_INFORMER_UPDATE,
	CVAR_INFORMER_POS,
	CVAR_INFORMER_COLOR
}

enum _:playersDataStruct {
	PLAYER_KILLS,
	PLAYER_NEEDKILLS,
	PLAYER_LEVEL
}

enum _:queState {
	HLXCE_LOAD_KILLS,
	HLXCE_PARSE_RANKS
}

new cvar[cvars],hlxceGame[32]

new Handle:sql,que[512]

new Array:ranksNames
new Array:ranksKills

new totalRanks
new bool:sqlFail

new playersKills[33][playersDataStruct]

new hudSyncObj

new Float:hudUpdateInterval
new Float:hudInfoxPos,Float:hudInfoyPos,hudInfoColor[3],bool:hudInfoColorRandom

new g_maxplayers

public plugin_init(){
	register_plugin(PLUGIN,VERSION,AUTHOR)
	
	new const cvarNames[cvars][][] = {
		{"hlxce_host","localhost"},		// hlxce host
		{"hlxce_user","mr.freeman"},		// hlxce user
		{"hlxce_password",""},			// hlxce password
		{"hlxce_db","hlxce"},			// hlxce db
		{"hlxce_game","valve"},			// hlxce game
		{"hlxce_informer_update","1.5"},	// informer update time
		{"hlxce_informer_pos","0.11 0.05"},	// informer positions [x y]
		{"hlxce_informer_color","100 100 100"}	// informer color [r g b] or [random]
	}
	
	for(new i ; i < cvars ; ++i)
		if(!(cvar[i] = get_cvar_pointer(cvarNames[i][0]))) // check that this cvar aren't register somewhere else
			cvar[i] = register_cvar(cvarNames[i][0],cvarNames[i][1])
			
	hudSyncObj = CreateHudSyncObj()
	g_maxplayers = get_maxplayers()
	
	register_dictionary("hlxce_hud_informer.txt")
}

public plugin_cfg(){
	// force amxx.cfg to execute
	server_exec()
	
	new hostname[128],user[64],password[64],db[64]
	
	get_pcvar_string(cvar[CVAR_HLXCE_HOST],hostname,charsmax(hostname))
	get_pcvar_string(cvar[CVAR_HLXCE_USER],user,charsmax(user))
	get_pcvar_string(cvar[CVAR_HLXCE_PASSWORD],password,charsmax(password))
	get_pcvar_string(cvar[CVAR_HLXCE_DB],db,charsmax(db))
	get_pcvar_string(cvar[CVAR_HLXCE_GAME],hlxceGame,charsmax(hlxceGame))
	
	sql = SQL_MakeDbTuple(hostname,user,password,db)
	
	// for UTF8 rank names u must use AMXX 1.8.3-dev-git3799 or higher
	#if AMXX_VERSION_NUM >= 183
		SQL_SetCharset(sql,"utf8")
	#endif
	
	new ranksCacheFile[513]
	get_localinfo("amxx_datadir",ranksCacheFile,charsmax(ranksCacheFile))
	add(ranksCacheFile,charsmax(ranksCacheFile),"/hlxce_ranks.ini")
	
	new f = fopen(ranksCacheFile,"r")
	
	if(f){  // check cache store
		new buff[256],rankName[128],rankMaxKills[10]
		
		ranksNames = ArrayCreate(128,1)
		ranksKills = ArrayCreate(1,1)
		
		while(!feof(f)){
			fgets(f,buff,255)
			trim(buff)
			
			if(!buff[0])
				continue
				
			parse(buff,rankName,127,rankMaxKills,9)
			
			ArrayPushString(ranksNames,rankName)
			ArrayPushCell(ranksKills,str_to_num(rankMaxKills))
		}
		
		totalRanks = ArraySize(ranksNames)
		
		fclose(f)
	}else{ // obtain new ranks from HLXCE database
		log_amx("start parsing ranks")
		
		formatex(que,charsmax(que),"SELECT `rankName`,`maxKills` FROM `hlstats_Ranks` WHERE `game` = '%s' ORDER BY `maxKills` ASC",hlxceGame)
		
		new data[charsmax(ranksCacheFile) + 1]
		
		data[0] = HLXCE_PARSE_RANKS
		formatex(data[1],charsmax(ranksCacheFile),ranksCacheFile[0])
		
		SQL_ThreadQuery(sql,"SQL_Handler",que,data,charsmax(data))
	}
	
	// load and cache informer settings
	new temp[15],sColor[3][6]
	
	get_pcvar_string(cvar[CVAR_INFORMER_COLOR],temp,14)
		
	if(strcmp(temp,"random") != 0){
		parse(temp,sColor[0],3,sColor[1],3,sColor[2],3)
		
		hudInfoColor[0] = str_to_num(sColor[0])
		hudInfoColor[1] = str_to_num(sColor[1])
		hudInfoColor[2] = str_to_num(sColor[2])
	}else
		hudInfoColorRandom = true
		
	get_pcvar_string(cvar[CVAR_INFORMER_POS],temp,14)
	parse(temp,sColor[0],5,sColor[1],5)
		
	hudInfoxPos = str_to_float(sColor[0])
	hudInfoyPos = str_to_float(sColor[1])
	
	hudUpdateInterval = get_pcvar_float(cvar[CVAR_INFORMER_UPDATE])
}

public client_death(killer,victim){
	if(!(0 < killer <= g_maxplayers))
		return
		
	playersKills[killer][PLAYER_KILLS] ++ // player killed something
	
	// check for levelup
	if(playersKills[killer][PLAYER_KILLS] >= playersKills[killer][PLAYER_NEEDKILLS]){
		playersKills[killer][PLAYER_LEVEL] = hlxce_get_level_for_kills(playersKills[killer][PLAYER_KILLS])
		playersKills[killer][PLAYER_NEEDKILLS] = ArrayGetCell(ranksKills,playersKills[killer][PLAYER_LEVEL])
	
		new players[32],pnum,usrName[32]
		get_players(players,pnum)
		get_user_name(killer,usrName,31)
		
		for(new i ; i < pnum ; ++i){
			if(players[i] != killer) // message for others
				client_print_color(players[i],print_team_default,"^1%L",killer,"HLXINF_NEWLEVEL_ALL",
					usrName,ArrayGetStringHandle(ranksNames,playersKills[killer][PLAYER_LEVEL])
				)
			else // message for this player
				client_print_color(killer,print_team_default,"^1%L",killer,"HLXINF_NEWLEVEL_ID",
					ArrayGetStringHandle(ranksNames,playersKills[killer][PLAYER_LEVEL])
				)
		}
	}
}

public client_authorized(id){
	if(sqlFail) // mysql failed for this map
		return
	
	if(ranksNames == Invalid_Array){ // hlxce db aren't initialized
		if(is_user_connected(id))
			set_task(1.0,"client_authorized",id) // force recheck
	
		return
	}
	
	arrayset(playersKills[id],-1,playersDataStruct)
	
	new authId[36]
	get_user_authid(id,authId,35) // NO STEAMID = NO SUPPORT :D
	
	new data[2]
	
	data[0] = HLXCE_LOAD_KILLS
	data[1] = id
	
	formatex(que,charsmax(que),"SELECT `s`.`kills` FROM `hlstats_PlayerUniqueIds` as `u`\
					INNER JOIN `hlstats_Players` as `s` ON `u`.`playerId` = `s`.`playerId`\
				    WHERE `u`.`uniqueId` =  '%s'",
		authId[8]) // hlxce saves without "STEAM_0:" part
	SQL_ThreadQuery(sql,"SQL_Handler",que,data,2)
}

public client_disconnect(id)
	remove_task(id + HUD_INFORMER_OFFSET)
	
// informer task
public Show_Hud_Informer(taskId){
	new id = taskId - HUD_INFORMER_OFFSET
	new watchId = id

	// check for spectating player
	if(!is_user_alive(id)){
		watchId = entity_get_int(id,EV_INT_iuser2)
		
		if(!watchId)
			return
	}
	
	if(playersKills[watchId][PLAYER_LEVEL] > -1){
		new hudMessage[256],len
		
		if(watchId != id){
			new watchName[32]
			get_user_name(watchId,watchName,31)
			
			len += formatex(hudMessage[len],charsmax(hudMessage) - len,"%L^n",
				id,"HLXINF_WATCH_PLAYER",
				watchName
			)
		}
		
		len += formatex(hudMessage[len],charsmax(hudMessage) - len,"%L",
			id,"HLXINF_MESSAGE",
				ArrayGetStringHandle(ranksNames,playersKills[watchId][PLAYER_LEVEL]),
				playersKills[watchId][PLAYER_KILLS],
				ArrayGetCell(ranksKills,playersKills[watchId][PLAYER_LEVEL])
			)
		
		if(hudInfoColorRandom){
			// рандом такой рандом
			hudInfoColor[0] = random(25500) / 100
			hudInfoColor[1] = random(25500) / 100
			hudInfoColor[2] = random(25500) / 100
		}
			
		set_hudmessage(hudInfoColor[0], hudInfoColor[1], hudInfoColor[2], hudInfoxPos , hudInfoyPos,.holdtime = hudUpdateInterval,.channel = 3)
		ShowSyncHudMsg(id,hudSyncObj,hudMessage)
	}
}

// sql handler
public SQL_Handler(failstate,Handle:sqlQue,err[],errNum,data[],dataSize){
	switch(failstate){
		case TQUERY_CONNECT_FAILED: {
			log_amx("MySQL connection failed")
			log_amx("[ %d ] %s",errNum,err)
			
			sqlFail = true

			return PLUGIN_HANDLED
		}
		case TQUERY_QUERY_FAILED: {
			new lastQue[512]
			SQL_GetQueryString(sqlQue,lastQue,511)
			
			log_amx("MySQL query failed")
			log_amx("[ %d ] %s",errNum,err)
			log_amx("[ SQL ] %s",lastQue)
			
			return PLUGIN_HANDLED
		}
	}

	switch(data[0]){
		case HLXCE_LOAD_KILLS:{
			new id = data[1]
			
			// no stats for this user
			if(!SQL_NumResults(sqlQue) || SQL_IsNull(sqlQue,0))
				return PLUGIN_HANDLED
			
			playersKills[id][PLAYER_KILLS] = SQL_ReadResult(sqlQue,0)
			playersKills[id][PLAYER_LEVEL] = hlxce_get_level_for_kills(playersKills[id][PLAYER_KILLS])
			playersKills[id][PLAYER_NEEDKILLS] = ArrayGetCell(ranksKills,playersKills[id][PLAYER_LEVEL])
			
			set_task(hudUpdateInterval,"Show_Hud_Informer",id + HUD_INFORMER_OFFSET,.flags="b") // init informer
		}
		case HLXCE_PARSE_RANKS:{
			new f = fopen(data[1],"w")
			
			if(!f){
				log_amx("failed to create cache file ^"%s^"",data[1])
				
				return PLUGIN_HANDLED
			}
			
			ranksNames = ArrayCreate(128,1)
			ranksKills = ArrayCreate(1,1)
		
			new rankName[128],rankMaxKills
			
			while(SQL_MoreResults(sqlQue)){
				SQL_ReadResult(sqlQue,0,rankName,charsmax(rankName))
				rankMaxKills = SQL_ReadResult(sqlQue,1)
				
				fprintf(f,"^"%s^" ^"%d^"^n",rankName,rankMaxKills) // write cache
				
				ArrayPushString(ranksNames,rankName)
				ArrayPushCell(ranksKills,rankMaxKills)
				
				SQL_NextRow(sqlQue)
			}
			
			totalRanks = ArraySize(ranksNames)
			
			log_amx("total %d ranks parsed and saved to cache file ^"%s^"",totalRanks,data[1])
			fclose(f)
		}
	}

	return PLUGIN_HANDLED
}

hlxce_get_level_for_kills(kills){
	for(new i ; i < totalRanks ; ++i){
		if(kills < ArrayGetCell(ranksKills,i))
			return i
	}
	
	return -1
}
