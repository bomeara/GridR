# 	GridR package
#	Copyright (C) 2008 Fraunhofer Institute Intelligent Analysis and Information Systems IAIS, Dennis Wegener (dennis.wegener@iais.fraunhofer.de), Malte Lohmeyer (malte.lohmeyer@iais.fraunhofer.de), Stefan Rueping (stefan.rueping@iais.fraunhofer.de)  name of author
#		
#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License Version 2
#	as published by the Free Software Foundation
#		
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#		
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

`grid.makeSshAndCondorFiles` <-
function(plots, yName, psName, fName, remScriptName, remMainName,remMainNameOut, varlist, cmd, onlyssh, check, batch=FALSE) {
	errName<- paste(.grid$uniqueName,"-err",sep="")
	condorName<-paste(.grid$uniqueName,"-script.condor",sep="")
	
	#remote script which loads libraries, checks if all functions and variables exist and then executes the main function. result is written to y
	# this script is executed by condor
	remscript <- "# automatically generated R script from gridR to be executed serverside
				options(warn=2)\n"
	if(plots){
	  remscript <- paste(remscript,"\nerr=try(library(graphics))
			if(inherits(err, \"try-error\")){
			write.table(\"try-error in RemScript: cannot load library graphics\",file=\"",yName,"\", quote=FALSE,row.names=FALSE,col.names=FALSE);q() };",
			paste("postscript(file=\"",psName,"\")",sep=""))
 	}
	remscript <- paste(remscript,"err=try(load(\"",fName,"\"))
				
		if(inherits(err, \"try-error\")){
		write.table(\"try-error in RemScript: cannot load fName. Please install GridR Package on serverside if batch mode is used \n\",file=\"",yName,"\", quote=FALSE,row.names=FALSE,col.names=FALSE);q() } 
		grid.input.Parameters=c() 
		err=try(library(codetools))
		if(inherits(err, \"try-error\")){
		write.table(\"try-error in RemScript: cannot load library codetools\",file=\"",yName,"\", quote=FALSE,row.names=FALSE,col.names=FALSE) ;q()} \n",sep="")
	if(check){
		if(!is.null(varlist))
			for(i in 1:length(varlist)){ 
				remscript=paste(remscript, "if(is.function(",varlist[i],")) checkUsage(",varlist[i],", report=function(s){assign(\"grid.input.Parameters\",paste(grid.input.Parameters, s), .GlobalEnv)}) \n", sep="")
			}
		remscript=paste(remscript,"checkUsage(grid.input.Parameters.f, report=function(s){assign(\"grid.input.Parameters\",paste(grid.input.Parameters, s), .GlobalEnv)}) \n if(is.null(grid.input.Parameters)) #otherwise checkUsage reports an error \n", sep="")
	}
	remscript=paste(remscript,"grid.input.Parameters = try(eval(parse(text=\"",cmd,"\"))) 
		if(inherits(err, \"try-error\")){
		write.table(paste(\"try-error in RemScript:\",err),file=\"",yName,"\", quote=FALSE,row.names=FALSE,col.names=FALSE) }
		save(list=c(\"grid.input.Parameters\"),file=\"",yName,"\")",sep="")
	if(plots)
		remscript <- append(remscript,"dev.off()")
	remscript <- append(remscript,"\n q(runLast=FALSE)")
	write.table(remscript,file=paste(remScriptName,sep=""),quote=FALSE,row.names=FALSE,col.names=FALSE)
	if(!onlyssh && batch==FALSE) {
        executable <- .grid$remoteRPath
        arguments <- "" 
        
        # If we want to bootstrap, build the arguments and package list
        if (.grid$bootstrap == TRUE) {
            executable <- system.file(package="GridR", "GridR", "R-bootstrap.py", mustWork=TRUE)
            if ( !is.null(.grid$Rurl) ) {
                arguments <- paste(" --url=", .grid$Rurl, sep="")
            }
            package_files <- ""
            if ( !is.null(.grid$remotePackages) ) {
                package_files <- paste(unlist(.grid$remotePackages), collapse=", ")
                for (package in .grid$remotePackages) {
                    arguments <- paste(arguments, " --package=", basename(package), sep="")
                }
            }
            arguments <- paste(arguments, " -- ")
        }
    
	  # create R script which submits the job to condor and waits until the file yName exists
		remMainScript=paste("condorScript=paste(\"Executable     = ",executable,"
			Universe       = vanilla
			should_transfer_files = YES
			when_to_transfer_output = ON_EXIT
			arguments      = ", arguments, "CMD BATCH --vanilla --slave ",remScriptName,"
			Error          = ",errName,"
			transfer_input_files =",remScriptName,",",fName, ",",package_files, 
			#"\ntransfer_files = ALWAYS",
			"\nQueue\", sep=\"\")
			write.table(condorScript,\"", condorName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)
			err=try(system(\"condor_submit ",condorName,"\", intern=TRUE))
			#look for condor errors
			out=scan(file=\"",remMainNameOut,"\", what=character(0), sep=\"\\n\")
			if(inherits(err, \"try-error\")) {
			write.table(\"remMainScript: cannot start condor_submit\",file=\"", yName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)}
			if(any(grep(\"^ERROR:\", out))) {
			write.table(paste(\"Condor:\", grep(\"^ERROR:\", out, value=TRUE)),file=\"", yName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)}
			if(any(grep(\"^WARNING:\", out))) {
			write.table(paste(\"Condor:\", grep(\"^WARNING:\", out, value=TRUE)),file=\"", yName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)}
			while(!file.exists(\"",yName,"\")){
			err=scan(file=\"",errName,"\", what=character(0), quiet=TRUE )
			if(length(err)>0) {
				write.table(paste(\"Condor error: \",err, sep=\"\"), file=\"", yName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)}
			else
				Sys.sleep(5)
			}
			q(runLast=FALSE)", sep="")
		write.table(remMainScript, remMainName,quote=FALSE,row.names=FALSE,col.names=FALSE)
	}
}


`grid.makeSshAndBoscoFiles` <-
function(plots, yName, psName, fName, remScriptName, remMainName,remMainNameOut, varlist, cmd, onlyssh, check, batch=FALSE) {
	errName<- paste(.grid$uniqueName,"-err",sep="")
    outName<- paste(.grid$uniqueName,"-out",sep="")
	condorName<-paste(.grid$uniqueName,"-script.condor",sep="")
	
	#remote script which loads libraries, checks if all functions and variables exist and then executes the main function. result is written to y
	# this script is executed by condor
	remscript <- "# automatically generated R script from gridR to be executed serverside
				options(warn=2)\n"
	if(plots){
	  remscript <- paste(remscript,"\nerr=try(library(graphics))
			if(inherits(err, \"try-error\")){
			write.table(\"try-error in RemScript: cannot load library graphics\",file=\"",yName,"\", quote=FALSE,row.names=FALSE,col.names=FALSE);q() };",
			paste("postscript(file=\"",psName,"\")",sep=""))
 	}
	remscript <- paste(remscript,"err=try(load(\"",fName,"\"))
				
		if(inherits(err, \"try-error\")){
		write.table(\"try-error in RemScript: cannot load fName. Please install GridR Package on serverside if batch mode is used \n\",file=\"",yName,"\", quote=FALSE,row.names=FALSE,col.names=FALSE);q() } 
		grid.input.Parameters=c() 
		err=try(library(codetools))
		if(inherits(err, \"try-error\")){
		write.table(\"try-error in RemScript: cannot load library codetools\",file=\"",yName,"\", quote=FALSE,row.names=FALSE,col.names=FALSE) ;q()} \n",sep="")
	if(check){
		if(!is.null(varlist))
			for(i in 1:length(varlist)){ 
				remscript=paste(remscript, "if(is.function(",varlist[i],")) checkUsage(",varlist[i],", report=function(s){assign(\"grid.input.Parameters\",paste(grid.input.Parameters, s), .GlobalEnv)}) \n", sep="")
			}
		remscript=paste(remscript,"checkUsage(grid.input.Parameters.f, report=function(s){assign(\"grid.input.Parameters\",paste(grid.input.Parameters, s), .GlobalEnv)}) \n if(is.null(grid.input.Parameters)) #otherwise checkUsage reports an error \n", sep="")
	}
	remscript=paste(remscript,"grid.input.Parameters = try(eval(parse(text=\"",cmd,"\"))) 
		if(inherits(err, \"try-error\")){
		write.table(paste(\"try-error in RemScript:\",err),file=\"",yName,"\", quote=FALSE,row.names=FALSE,col.names=FALSE) }
		save(list=c(\"grid.input.Parameters\"),file=\"",yName,"\")",sep="")
	if(plots)
		remscript <- append(remscript,"dev.off()")
	remscript <- append(remscript,"\n q(runLast=FALSE)")
	write.table(remscript,file=paste(remScriptName,sep=""),quote=FALSE,row.names=FALSE,col.names=FALSE)
    
    arguments <- "" 
    if ( !is.null(.grid$Rurl) ) {
        arguments <- paste(" --url=", .grid$Rurl, sep="")
    }
    package_files <- ""
    if ( !is.null(.grid$remotePackages) ) {
        package_files <- paste(unlist(.grid$remotePackages), collapse=", ")
        for (package in .grid$remotePackages) {
            arguments <- paste(arguments, " --package=", basename(package), sep="")
        }
        
        
    }
    
	if(!onlyssh && batch==FALSE) {
	
	  # create R script which submits the job to condor and waits until the file yName exists
		remMainScript=paste("condorScript=paste(\"Executable     = ", system.file(package="GridR", "GridR", "R-bootstrap.py"), "
			Universe       = grid
			should_transfer_files = YES
			when_to_transfer_output = ON_EXIT
			arguments      = ", arguments," -- CMD BATCH --vanilla --slave ",remScriptName,"
			Error          = ",errName,"
            Output         = ",outName,"
			transfer_input_files =",remScriptName,",",fName, ", ", package_files, "
            transfer_output_files =",yName, 
            #environment = \\\"PATH=$PATH:~/bosco/R/bin R_ROOT_DIR=~/bosco/R RHOME=${R_ROOT_DIR} \\\" ",
			#"\ntransfer_files = ALWAYS",
			"\nQueue\", sep=\"\")
			write.table(condorScript,\"", condorName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)
			err=try(system(\"source ~/bosco/bosco.sh; condor_submit ",condorName,"\", intern=TRUE))
			#look for condor errors
			out=scan(file=\"",remMainNameOut,"\", what=character(0), sep=\"\\n\")
			if(inherits(err, \"try-error\")) {
			write.table(\"remMainScript: cannot start condor_submit\",file=\"", yName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)}
			if(any(grep(\"^ERROR:\", out))) {
			write.table(paste(\"Condor:\", grep(\"^ERROR:\", out, value=TRUE)),file=\"", yName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)}
			if(any(grep(\"^WARNING:\", out))) {
			write.table(paste(\"Condor:\", grep(\"^WARNING:\", out, value=TRUE)),file=\"", yName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)}
			while(!file.exists(\"",yName,"\") || file.info(\"",yName,"\")$size==0){
			err=scan(file=\"",errName,"\", what=character(0), quiet=TRUE )
			if(length(err)>0) {
				write.table(paste(\"Condor error: \",err, sep=\"\"), file=\"", yName,"\",quote=FALSE,row.names=FALSE,col.names=FALSE)}
			else
				Sys.sleep(5)
			}
			q(runLast=FALSE)", sep="")
		write.table(remMainScript, remMainName,quote=FALSE,row.names=FALSE,col.names=FALSE)
	}
}



