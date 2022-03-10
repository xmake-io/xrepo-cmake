#include <gflags/gflags.h>
#include <glog/logging.h>
#include <pcre2.h>

int main(int argc, char** argv)
{
    google::InitGoogleLogging(argv[0]);
    gflags::SetUsageMessage("xrepo-cmake example app.");
    gflags::ParseCommandLineFlags(&argc, &argv, true);

    FLAGS_logtostderr = 1;

    LOG(INFO) << "hello xrepo";

    pcre2_general_context* gctx = pcre2_general_context_create(NULL, NULL, NULL);
    if (gctx) {
        pcre2_general_context_free(gctx);
    }

    return 0;
}
