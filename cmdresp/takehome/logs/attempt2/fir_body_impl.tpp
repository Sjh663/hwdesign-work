// FIR implementation; generated boundary includes this file.
#ifndef FIR_BODY_IMPL_TPP
#define FIR_BODY_IMPL_TPP
#include "include/fir_cmd_hdr.h"
#include "include/fir_resp_hdr.h"
#include "include/float32_array_utils.h"
namespace fir_impl {
static float fp32_mul(float a,float b) {
#pragma HLS INLINE off
#pragma HLS EXPRESSION_BALANCE off
    float p=a*b;
#pragma HLS BIND_OP variable=p op=fmul
    return p;
}
static float fp32_add(float a,float b) {
#pragma HLS INLINE off
#pragma HLS EXPRESSION_BALANCE off
    float s=a+b;
#pragma HLS BIND_OP variable=s op=fadd
    return s;
}
static void fail(unsigned code,ap_uint<32> tx,ap_uint<1>& halted,ap_uint<8>& error,ap_uint<32>& tx_id){
#pragma HLS INLINE
    halted=1;error=code;tx_id=tx;
}
template<int in_bw,int out_bw>
void body(hls::stream<streamutils::axi4s_word<in_bw>>& s_in,hls::stream<streamutils::axi4s_word<out_bw>>& m_out,ap_uint<1>& halted,ap_uint<8>& error,ap_uint<32>& tx_id){
#pragma HLS INLINE
#pragma HLS EXPRESSION_BALANCE off
    float taps[64],history[63];unsigned K=0;bool configured=false;
#pragma HLS ARRAY_PARTITION variable=history complete dim=1
    halted=0;error=0;tx_id=0;
init_taps:for(int j=0;j<64;++j){
#pragma HLS PIPELINE II=1
        taps[j]=0.0f;
    }
init_history:for(int j=0;j<63;++j){
#pragma HLS UNROLL
        history[j]=0.0f;
    }
commands:while(true){
        FirCmdHdr h;h.template read_axi4_stream<in_bw>(s_in);
        const unsigned op=(unsigned)h.opcode,count=(unsigned)h.count;const ap_uint<32> tx=h.tx_id;
        if(op!=1&&op!=2&&op!=3){fail(1,tx,halted,error,tx_id);return;}
        if(op==3)return;
        if(op==2&&!configured){fail(2,tx,halted,error,tx_id);return;}
        if(op==1&&(count==0||count>64)){fail(3,tx,halted,error,tx_id);return;}
        if(op==2&&(count==0||count>4096)){fail(4,tx,halted,error,tx_id);return;}
        if(op==1){
config_taps:for(unsigned j=0;j<count;++j){
#pragma HLS LOOP_TRIPCOUNT min=1 max=64
                float x[1];streamutils::tlast_status status;
                float32_array_utils::template read_axi4_stream_lane<in_bw>(s_in,x,1,status);
                const auto expected=(j+1==count)?streamutils::tlast_status::tlast_at_end:streamutils::tlast_status::no_tlast;
                if(status!=expected){fail(5,tx,halted,error,tx_id);return;}
                taps[j]=x[0];
            }
clear_history:for(int j=0;j<63;++j){
#pragma HLS UNROLL
                history[j]=0.0f;
            }
            K=count;configured=true;FirRespHdr r;r.tx_id=tx;r.template write_axi4_stream<out_bw>(m_out,true);
        }else{
            bool pending_valid=false;float pending=0.0f;
process_samples:for(unsigned n=0;n<count;++n){
#pragma HLS LOOP_TRIPCOUNT min=1 max=4096
                float x[1];streamutils::tlast_status status;
                float32_array_utils::template read_axi4_stream_lane<in_bw>(s_in,x,1,status);
                const auto expected=(n+1==count)?streamutils::tlast_status::tlast_at_end:streamutils::tlast_status::no_tlast;
                if(status!=expected){
                    if(pending_valid){float y[1]={pending};float32_array_utils::template write_axi4_stream_lane<out_bw>(y,m_out,true,1);}
                    fail(5,tx,halted,error,tx_id);return;
                }
                if(!pending_valid){FirRespHdr r;r.tx_id=tx;r.template write_axi4_stream<out_bw>(m_out,true);}
                float sum=0.0f;
tap_loop:for(unsigned k=0;k<K;++k){
#pragma HLS PIPELINE II=1
#pragma HLS LOOP_TRIPCOUNT min=1 max=64
                    float delayed=(k==0)?x[0]:history[k-1];float product=fp32_mul(taps[k],delayed);sum=fp32_add(sum,product);
                }
shift_history:for(int j=62;j>0;--j){
#pragma HLS UNROLL
                    history[j]=history[j-1];
                }
                history[0]=x[0];
                if(pending_valid){float y[1]={pending};float32_array_utils::template write_axi4_stream_lane<out_bw>(y,m_out,false,1);}
                pending=sum;pending_valid=true;
            }
            if(pending_valid){float y[1]={pending};float32_array_utils::template write_axi4_stream_lane<out_bw>(y,m_out,true,1);}
        }
    }
}
}
#endif
