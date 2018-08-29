export DSS_CAPI_VERSION=`grep DSS_CAPI_V7_VERSION include/v7/dss_capi.h | grep -o '".*"' | grep -o '[^"]*'`
export DSS_CAPI_REV=`git rev-parse HEAD`
export DSS_CAPI_SVN_REV=`git --git-dir=../electricdss-src/.git log | grep -m 1 -E "trunk@[0-9]+" -o | grep -E "[0-9]+" -o`

echo "UNIT CAPI_metadata;" > src/CAPI_Metadata.pas
echo "INTERFACE" >> src/CAPI_Metadata.pas
echo "" >> src/CAPI_Metadata.pas
echo "Const" >> src/CAPI_Metadata.pas
echo "   DSS_CAPI_VERSION='${DSS_CAPI_VERSION}';" >> src/CAPI_Metadata.pas
echo "   DSS_CAPI_REV='${DSS_CAPI_REV}';" >> src/CAPI_Metadata.pas
echo "   DSS_CAPI_SVN_REV='${DSS_CAPI_SVN_REV}';" >> src/CAPI_Metadata.pas
echo "" >> src/CAPI_Metadata.pas
echo "IMPLEMENTATION" >> src/CAPI_Metadata.pas
echo "" >> src/CAPI_Metadata.pas
echo "END." >> src/CAPI_Metadata.pas
