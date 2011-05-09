<cfcomponent displayname="Same Origin" output="false">
	<!---
		Name			: SameOrigin.cfc
		Author			: Michael Sharman (michael@chapter31.com)
		Created			: May 06, 2011
		Last Updated		: May 06, 2011
		History			: Initial release (mps 06/05/2011)
		Purpose			: Ensures form POSTs are coming in from the same server that loaded the form
		Caveat(s)			: You need to have session management enabled for this to work, it will do 
						: no checking if session management is not enabled (you can decide whether to throw an exception or not in this case)
						: Sticky sessions must be used when in a cluster, if sessions are replicated across the cluster this
						: won't work as we're using SameOrigin as a singleton (i.e. a separate SameOrigin instance for each server in the cluster).
		Usage			: See https://github.com/michaelsharman/cfsameorigin/
		Example			:
			<cfif structKeyExists(form, "username")>
			        <cfset valid = application.cfcs.SameOrigin.check("login", form["__sononce"])>
			        <cfif valid>
			                <!--- All good, continue to process form --->
			        </cfif>
			</cfif>
			
			<form id="frm" action="" method="post">
			        #application.cfcs.SameOrigin.write("login")#
			        <input type="text" name="username" id="username" />
			        <input type="password" name="password" id="password" />
			        <input type="submit" name="btnSubmit" id="btnSubmit" value="Submit" />
			</form>
	 --->
	
	<cffunction name="init" access="public" output="false" returnType="SameOrigin">
		<cfargument name="sameOriginName" type="string" required="false" hint="Use if you want a specific name for your 'same origin' key in session (and hidden form field prefix)">
		<cfargument name="throwOnNoSession" type="boolean" required="false" default="true" hint="Should we throw an exception if sessions are not enabled but a call is made to SameOrigin?">
		
		<cfscript>
			variables.instance = structNew();
			variables.instance.sameOriginName = "__sononce"; // Default
			variables.instance.throwOnNoSession = arguments.throwOnNoSession;
			
			if (structKeyExists(arguments, "sameOriginName") AND len(trim(arguments.sameOriginName)))
			{
				variables.instance.sameOriginName = trim(arguments.sameOriginName);
			}
			
			return this;
		</cfscript>	
	</cffunction>
	
	
	<cffunction name="check" access="public" output="false" returnType="boolean">
		<cfargument name="key" type="string" required="true" hint="The form nonce word (key) to check">
		<cfargument name="nonce" type="string" required="true" hint="The actual nonce word value to check">
		
		<cfscript>
			var check = false;
			var fieldKey = sanitise(arguments.key);
		
			if (isSessionEnabled())
			{
				check = getNonce(fieldKey, arguments.nonce);
			}
		
			return check;
		</cfscript>
	</cffunction>
	
	
	<cffunction name="deleteNonce" access="private" output="false" returnType="void" hint="Removes a key based nonce from session once the form has been submitted">
		<cfargument name="key" type="string" required="true" hint="Key to remove">
		
		<cfscript>
			var sess = getSession();
			
			if (structKeyExists(sess, variables.instance.sameOriginName))
			{
				structDelete(sess[variables.instance.sameOriginName], arguments.key);
			}
		</cfscript>			
	</cffunction>
	
	
	<cffunction name="getNonce" access="private" output="false" returntype="boolean">
		<cfargument name="key" type="string" required="true">
		<cfargument name="nonce" type="string" required="true">
		
		<cfscript>
			var nonceExists = false;
			var sess = getSession();
			var fieldKey = arguments.key;
	
			if (structKeyExists(sess, variables.instance.sameOriginName))
			{
				if (structKeyExists(sess[variables.instance.sameOriginName], fieldKey) AND sess[variables.instance.sameOriginName][fieldKey] EQ arguments.nonce)
				{
					nonceExists = true;
					deleteNonce(fieldKey);
				}
			}
			
			return nonceExists;
		</cfscript>
	</cffunction>
	

	<cffunction name="getSession" access="private" output="false" returnType="struct"  hint="Handles calls to and from session">

		<cfreturn session>
	</cffunction>

	
	<cffunction name="isSessionEnabled" access="private" output="false" returnType="boolean">
		
		<cfset var sessionsEnabled = application.getApplicationSettings().sessionmanagement>
			
		<cfif (NOT sessionsEnabled AND variables.instance.throwOnNoSession)>
			<cfthrow type="sameorigin.nosession" message="Invalid SameOrigin call, sessions are not enabled!">
		</cfif>
			
		<cfreturn sessionsEnabled>
	</cffunction>
	

	<cffunction name="sanitise" access="private" output="false" returnType="string" hint="Cleans up key/form field value">
		<cfargument name="key" type="string" required="true" hint="Session/form field key name">
		
		<cfscript>
			var fieldKey = replace(arguments.key, " ", "_", "all");
			
			return fieldKey;
		</cfscript>
	</cffunction>

	
	<cffunction name="setNonce" access="private" output="false" returntype="void">
		<cfargument name="key" type="string" required="true">
		<cfargument name="nonce" type="string" required="true">
		
		<cfscript>
			var sess = getSession();
			
			if (NOT structKeyExists(sess, variables.instance.sameOriginName))
			{
				sess[variables.instance.sameOriginName] = structNew();	
			}
			
			sess[variables.instance.sameOriginName][arguments.key] = arguments.nonce;
		</cfscript>
	</cffunction>


	<cffunction name="write" access="public" output="false" returnType="string" hint="Creates session based nonce word and returns a hidden form field">
		<cfargument name="key" type="string" required="true" hint="Unique form name from the application">
		
		<cfscript>			
			var nonce = createUUID();
			var output = "";
			var fieldKey = sanitise(arguments.key);
			var frmId = variables.instance.sameOriginName & "__" & fieldKey;
			
			if (isSessionEnabled())
			{
				setNonce(fieldKey, nonce);
				output = '<input type="hidden" name="#variables.instance.sameOriginName#" id="#frmId#" value="#nonce#" />';
			}
			
			return output;
		</cfscript>		
	</cffunction>
	
	
	<cffunction name="writeLog" access="private" output="false" returnType="void">
		<cfargument name="scenario" type="string" required="true">
		<cfargument name="key" type="string" required="true" hint="Form name being loaded">
		<cfargument name="type" type="string" required="true">
	
		<cfset var output = "">
		
		<!--- Note: currently deprecated --->
		
		<cfswitch expression="#arguments.scenario#">
			<cfcase value="nosession">
				<cfset output = "SameOrigin: Session scope is not enabled, but same origin was called on #arguments.key#">
			</cfcase>
			<cfdefaultcase></cfdefaultcase>
		</cfswitch>
		
		<cfif len(trim(output))>
			<cflog text="#output#" type="#arguments.type#" file="#application.applicationName#">
		</cfif>	
	</cffunction>


</cfcomponent>