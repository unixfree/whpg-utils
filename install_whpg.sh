sudo -iu gpadmin

sudo vi /etc/hosts

cd whpg6_redhat8
sudo dnf install *.rpm

sudo chown -R gpadmin:gpadmin /usr/local/greenplum-db*
sudo chown -R gpadmin:gpadmin /usr/local/edb-*

source /usr/local/greenplum-db/greenplum_path.sh 
cp -r /usr/local/greenplum-db/docs/cli_help/gpconfigs .
mv gpconfigs/gpinitsystem_config gpconfigs/gpinitsystem
vi gpconfigs/gpinitsystem

vi gpconfigs/hostfile_gpinitsystem

sudo mkdir -p /data/primary
sudo mkdir -p /data/mirror

gpinitsystem -c gpconfigs/gpinitsystem -n gpconfigs/hostfile_gpinitsystem



