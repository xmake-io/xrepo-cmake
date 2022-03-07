#include <gflags/gflags.h>
#include <glog/logging.h>
#include <pcre2.h>

using GFLAGS_NAMESPACE::SetUsageMessage;

int main(int argc, char** argv)
{
    pcre2_general_context* gctx = pcre2_general_context_create(NULL, NULL, NULL);
    if (gctx) {
        pcre2_general_context_free(gctx);
    }
    ::google::InitGoogleLogging(argv[0]);
    FLAGS_logtostderr = 1;
    SetUsageMessage("Usage message");
    LOG(INFO) << "hello xrepo";
    return 0;
}
