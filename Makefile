TOP_DIR = ../..
DEPLOY_RUNTIME ?= /disks/patric-common/runtime
TARGET ?= /tmp/deployment
include $(TOP_DIR)/tools/Makefile.common

SERVICE_SPEC = 
SERVICE_NAME = p3_solr_service
SERVICE_PORT = 8983
SERVICE_DIR  = $(SERVICE_NAME)

SCHEMA_REPO = https://github.com/PATRIC3/patric_solr
SCHEMA_DIR = patric_solr
SOLR_HOME = 
SOLR_HEAP_MEMORY = 12g
SOLR_STACK_MEMORY = 8g
SOLR_LUCENE_VERSION = 5.5

SERVICE_PSGI = $(SERVICE_NAME).psgi
TPAGE_ARGS = --define kb_runas_user=$(SERVICE_USER) \
	--define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define kb_service_name=$(SERVICE_NAME) \
	--define kb_service_dir=$(SERVICE_DIR) \
	--define kb_service_port=$(SERVICE_PORT) \
	--define kb_psgi=$(SERVICE_PSGI) \
	--define kb_solr_home=$(SOLR_HOME) \
	--define kb_solr_stack_memory=$(SOLR_STACK_MEMORY) \
	--define kb_solr_heap_memory=$(SOLR_HEAP_MEMORY) \
	--define kb_solr_lucene_version=$(SOLR_LUCENE_VERSION)


# to wrap scripts and deploy them to $(TARGET)/bin using tools in
# the dev_container. right now, these vars are defined in
# Makefile.common, so it's redundant here.
TOOLS_DIR = $(TOP_DIR)/tools
WRAP_PERL_TOOL = wrap_perl
WRAP_PERL_SCRIPT = bash $(TOOLS_DIR)/$(WRAP_PERL_TOOL).sh
SRC_PERL = $(wildcard scripts/*.pl)


default:

dist: 

test: 

deploy: deploy-client deploy-service

deploy-all: deploy-client deploy-service

deploy-client: 

deploy-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib bash ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done

deploy-service: deploy-run-scripts deploy-schema

#
# We only check out and push the schema if SOLR_HOME does not exist
#
deploy-schema: 
	if [ "$(SOLR_HOME)" = "" ] ; then \
		echo "SOLR_HOME not defined, exiting" 1>&2 ; \
		exit 1 ; \
	fi
	if [ ! -d $(SOLR_HOME) ] ; then \
		mkdir $(SOLR_HOME); \
		mkdir tmp_install; cd tmp_install; \
		git clone $(SCHEMA_REPO) $(SCHEMA_DIR) ; \
		rsync -arv $(SCHEMA_DIR)/* $(SOLR_HOME); \
	fi

deploy-run-scripts:
	mkdir -p $(TARGET)/services/$(SERVICE_DIR)
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERVICE_DIR)/start_service
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERVICE_DIR)/stop_service
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/stop_service
	if [ -f service/upstart.tt ] ; then \
		$(TPAGE) $(TPAGE_ARGS) service/upstart.tt > service/$(SERVICE_NAME).conf; \
	fi
	echo "done executing deploy-service target"

deploy-upstart: deploy-service
	-cp service/$(SERVICE_NAME).conf /etc/init/
	echo "done executing deploy-upstart target"

deploy-cfg:

deploy-docs:
	-mkdir -p $(TARGET)/services/$(SERVICE_DIR)/webroot/.
	cp docs/*.html $(TARGET)/services/$(SERVICE_DIR)/webroot/.


build-libs:

include $(TOP_DIR)/tools/Makefile.common.rules
