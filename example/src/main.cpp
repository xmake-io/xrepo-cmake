#include <gflags/gflags.h>

using GFLAGS_NAMESPACE::SetUsageMessage;

int main(int argc, char** argv)
{
    SetUsageMessage("Usage message");
    return 0;
}
