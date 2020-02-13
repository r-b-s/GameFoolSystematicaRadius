use Kustom
go
create table Fl_DeckDic
(
    Id int identity
    ,val int
    ,color char(3)
    ,pic varchar(6)
)

go
create table Fl_Sessions
(
    Id int identity
    ,OwnerUser_Id int
    ,Status char(1)
    ,MainColor char(3) null
    ,BeginAt datetime    
)
go
create table Fl_Users
(
    Ord int identity
    ,Session_Id  int 
    ,User_Id int  
    ,BotLevel int null  
    ,Status char(1) null
)
go
create table Fl_Hands
(
     Session_Id  int
     ,User_Id int 
     ,Card_Id int 
)
go
create table Fl_Tables
(
    Ord  int identity
    ,Session_Id  int    
    ,Move_Card_Id int
    ,Beat_Card_Id int null
)
go
create table Fl_Decks
(
    Ord  int identity
    ,Session_Id  int    
    ,Card_Id int
)
go           
create table Fl_Actions
(
    Session_Id  int    
    ,txt varchar(100)
    ,NextAction_UserId int
    ,rdt datetime default getdate()
    ,FirstMove_UserId int
    ,Beat_UserId int null
    ,PassCounter int default 0 
    ,MoveUser_Id int null
    ,TakeFlag char(1) default ' '   
)
go       

truncate table Fl_DeckDic
go
declare @i int

select @i=6


while @i<15
begin
    insert Fl_DeckDic
    select @i,'Чер',cast(@i as varchar)
    insert Fl_DeckDic
    select @i,'Буб',cast(@i as varchar)
    insert Fl_DeckDic
    select @i,'Трф',cast(@i as varchar)
    insert Fl_DeckDic
    select @i,'Пик',cast(@i as varchar)
   select @i=@i+1 
end

update Fl_DeckDic
set pic='Валет'
where pic='11'
update Fl_DeckDic
set pic='Дама'
where pic='12'
update Fl_DeckDic
set pic='Король'
where pic='13'
update Fl_DeckDic
set pic='Туз'
where pic='14'  

go


create  procedure Fl_MakeDeck
(
    @Session_Id int
    ,@LastCard_Id int  out
)
as

insert Fl_Decks
select   @Session_Id,Id from Fl_DeckDic      
order by    Rand(Id*(cast( str_replace(right(convert(varchar, getdate(),20),3),':',null) as int)+val))

select top 1 @LastCard_Id=Card_Id from Fl_Decks   where  Session_Id=@Session_Id  order by Ord desc
  
go
create procedure Fl_GetCard
(
    @Session_Id int
    ,@Card_Id int out
)
as


select top 1 @Card_Id=Card_Id from  Fl_Decks
where Session_Id= @Session_Id
order by Ord

delete  from  Fl_Decks
where Session_Id= @Session_Id
and Card_Id=@Card_Id

go


create procedure Fl_NextUser
(
    @Session_Id int
   ,@User_Id int
   ,@ExUser_Id int
   ,@NextUser_Id int out
)   
as

select top 1 @NextUser_Id=u2.User_Id
from Fl_Users u
join Fl_Users u2 on u.Session_Id=u2.Session_Id and u2.Ord>u.Ord
where u.Session_Id=@Session_Id and u2.Status not in ('W')
    and u.User_Id=@User_Id
    and  u2.User_Id<>@ExUser_Id
order by u2.Ord     

if @@rowcount=0
    select top 1 @NextUser_Id=u2.User_Id
    from Fl_Users u2 
    where u2.Session_Id=@Session_Id and u2.Status not in ('W')
        and  u2.User_Id<>@ExUser_Id
    order by Ord    

go


create procedure Fl_Start
(
    @User_Id int
    ,@User2 int
    ,@User3 int
    ,@User4 int
    ,@User5 int
    ,@User6 int
    ,@Session_Id int out
)    
as
declare 
    @LastCard_Id int
    ,@i int
    ,@cur int
    ,@Card_Id int
    ,@mainColor char(3)
    ,@lowTrump int
    ,@beatUser int
    ,@rdt datetime
    

if (select max(BeginAt) from Fl_Sessions)<dateadd(dd,-1,getdate())
    begin
    truncate table   Fl_Actions
    truncate table  Fl_Decks
    truncate table  Fl_Hands
    truncate table  Fl_Tables
    truncate table  Fl_Users
    --truncate table  Fl_Sessions
    end
    
    
begin tran  

insert Fl_Sessions 
select @User_Id ,'S',null,getdate()  

select   @Session_Id=@@IDENTITY 

exec  Fl_MakeDeck @Session_Id ,@LastCard_Id out

select @mainColor=color from Fl_DeckDic where Id=@LastCard_Id

update   Fl_Sessions set MainColor=@mainColor where Id= @Session_Id


 
insert Fl_Users (Session_Id,User_Id,Status) select @Session_Id,@User_Id ,'C'
insert Fl_Users (Session_Id,User_Id,Status) select @Session_Id,@User2  ,'C'--must be
if isnull(@User3,0)<>0
    insert Fl_Users (Session_Id,User_Id,Status) select @Session_Id,@User3 ,'C'   
if isnull(@User4,0)<>0
    insert Fl_Users (Session_Id,User_Id,Status) select @Session_Id,@User4  ,'C'
if isnull(@User5,0)<>0
    insert Fl_Users (Session_Id,User_Id,Status) select @Session_Id,@User5  ,'C'
if isnull(@User6,0)<>0
    insert Fl_Users (Session_Id,User_Id,Status) select @Session_Id,@User6  ,'C'



declare  usersCur  cursor for
select User_Id from Fl_Users where Session_Id=@Session_Id

OPEN usersCur
fetch usersCur into @cur
WHILE (@@sqlstatus = 0)
BEGIN
    select @i=0
    while @i<6
    begin
        exec Fl_GetCard @Session_Id  ,@Card_Id out
        insert Fl_Hands select @Session_Id,@cur,@Card_Id
        select @i=@i+1
    end
    
    FETCH usersCur into @cur
END

CLOSE usersCur
DEALLOCATE usersCur 

    
insert Fl_Actions
select  @Session_Id,'Раздача '+cast(@Session_Id as varchar)+'. Козырь '+@mainColor,0 ,getdate() ,0,null,0 ,0,' '


waitfor delay  '00:00:01'

select @lowTrump=d.Id ,@cur=h.User_Id
from Fl_DeckDic d                 
join Fl_Hands h on h.Card_Id=d.Id
where d.color= @mainColor
    and h.Session_Id=@Session_Id 
    and d.val=(select min(d.val) from Fl_DeckDic d                 
                                join Fl_Hands h on h.Card_Id=d.Id
                                where d.color= @mainColor
                                    and h.Session_Id=@Session_Id 
                                    ) 
     
  
set @rdt=getdate()    
if @@rowcount=0 or  @lowTrump=0
begin 
     select  @cur=@User_Id   

    insert Fl_Actions ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId ,MoveUser_Id )  
    select @Session_Id,'Нет козырей на руках. Ходит '+ku.Users_ShortName,u.User_Id ,@rdt ,u.User_Id, u.User_Id 
    from Fl_Users u
    join kplus..Users ku on ku.Users_Id=u.User_Id
    where User_Id=@User_Id
        and u.Session_Id= @Session_Id

end          
else   
begin
    insert Fl_Actions  ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId ,MoveUser_Id )
    select @Session_Id,'Ходит '+ku.Users_ShortName+' ('+d.pic+' '+d.color+')',u.User_Id ,@rdt,u.User_Id ,u.User_Id 
    from Fl_Users u
    join kplus..Users ku on ku.Users_Id=u.User_Id
    join Fl_Hands h on h.Session_Id=u.Session_Id and h.User_Id=u.User_Id  
    join Fl_DeckDic d on d.Id=h.Card_Id
    where u.Session_Id=@Session_Id
        and h.Card_Id=@lowTrump                
        
    

end        

exec Fl_NextUser @Session_Id,@cur,0,@beatUser out


   
update  Fl_Actions
set  Beat_UserId=@beatUser
where Session_Id=@Session_Id
    and rdt=@rdt    
        
commit 

insert into Kustom..RadiusJongleur 
select 'S', getdate(), null, null, null, null, 'N', 'RADIUS.FUN.FL.'+cast(@Session_Id as varchar), '', 0 , 'N' 
exec Kustom..sp_Jongleur_Notify
   
go
              

create procedure   Fl_ProcMOVE
(
      @Session_Id int
     ,@User_Id int
     ,@Card_Id int   
)
as
if exists( select 1 
            from Fl_Tables t
            where t.Session_Id=@Session_Id

        )
begin
    if not exists(select 1 
        from Fl_Tables t 
            ,Fl_DeckDic dd 
            ,Fl_DeckDic ddc  
        where t.Session_Id=@Session_Id
            and   dd.Id=t.Move_Card_Id
            and ddc.Id=@Card_Id
            and ddc.val=dd.val
        )
     and not  exists(select 1 
        from Fl_Tables t 
            ,Fl_DeckDic dd 
            ,Fl_DeckDic ddc  
        where t.Session_Id=@Session_Id
            and   dd.Id=t.Beat_Card_Id
            and ddc.Id=@Card_Id
            and ddc.val=dd.val
        )
        return 
end     

insert  dbo.Fl_Tables
select     @Session_Id     , @Card_Id  ,  null
  
delete from Fl_Hands where Session_Id=@Session_Id and User_Id= @User_Id and Card_Id=@Card_Id



declare @Result varchar(10)
    ,@FirstUser_Id int
    ,@BeatUser_Id int
    ,@NextUser_Id int
    ,@ExUser_Id int
    ,@TakeFlag char(1)

select top 1
         @FirstUser_Id=a.FirstMove_UserId
         ,@BeatUser_Id=a.Beat_UserId
         , @ExUser_Id=0
         ,@TakeFlag=a.TakeFlag
    from Fl_Actions a
    where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
    order by a.rdt desc
    
if @TakeFlag='T'
begin
    insert Fl_Actions   ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId ,MoveUser_Id ,TakeFlag)       
    select top 1
     @Session_Id
        ,u1.Users_ShortName + ' подкинул '+d.pic+' '+d.color
        ,@User_Id
        ,getdate()
        ,a.FirstMove_UserId
        ,a.Beat_UserId
        ,@User_Id
        ,'T'
from Fl_Actions a
        join kplus..Users u1 on u1.Users_Id= @User_Id
        join Fl_DeckDic d on d.Id=@Card_Id  
    where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
    order by a.rdt desc
end    
else begin
  
insert Fl_Actions   ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId ,MoveUser_Id )       
select top 1
     @Session_Id
        ,u1.Users_ShortName + ' кинул '+d.pic+' '+d.color+ '. Отбивается '+u2.Users_ShortName
        ,a.Beat_UserId
        ,getdate()
        ,a.FirstMove_UserId
        ,a.Beat_UserId
        ,@User_Id
from Fl_Actions a
        join kplus..Users u1 on u1.Users_Id= @User_Id
        join kplus..Users u2 on u2.Users_Id= a.Beat_UserId
        join Fl_DeckDic d on d.Id=@Card_Id  
    where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
    order by a.rdt desc
end      

go


create procedure   Fl_ProcPASS
(
      @Session_Id int
     ,@User_Id int    
     ,@Result varchar(10) out  
)
as
declare @Beat_UserId int, @NextUser_Id int  ,@PassCount int

select top 1  @Beat_UserId=a.Beat_UserId,@PassCount=a.PassCounter
from Fl_Actions a
where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
order by a.rdt desc

if @PassCount>=(select count(*)-2 from Fl_Users where Session_Id=@Session_Id and Status not in('W'))
begin                                                     
    
  insert  Fl_Actions  ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId ,MoveUser_Id ,TakeFlag)   
    select top 1
         @Session_Id
        ,u1.Users_ShortName + ' пасует. '
        ,a.NextAction_UserId
        ,getdate()
        ,a.FirstMove_UserId
        ,a.Beat_UserId
        ,@User_Id
        ,a.TakeFlag
    from Fl_Actions a
        join kplus..Users u1 on u1.Users_Id= @User_Id        
    where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
    order by a.rdt desc
    
      
    select @Result='EndRound'
    return
end



exec Fl_NextUser @Session_Id, @User_Id, @Beat_UserId, @NextUser_Id out
  

insert  Fl_Actions  ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId,PassCounter ,MoveUser_Id ,TakeFlag)   
select top 1
         @Session_Id
        ,u1.Users_ShortName + ' пасует. Подкидывает '+u2.Users_ShortName
        ,@NextUser_Id
        ,getdate()
        ,a.FirstMove_UserId
        ,a.Beat_UserId
        ,a.PassCounter+1 
        ,@NextUser_Id 
        ,a.TakeFlag
    from Fl_Actions a
        join kplus..Users u1 on u1.Users_Id= @User_Id
        join kplus..Users u2 on u2.Users_Id= @NextUser_Id 
    where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
    order by a.rdt desc

  
go


create procedure   Fl_ProcBEAT
(
      @Session_Id int
     ,@User_Id int   
     ,@Card_Id int 
     ,@Result varchar(10) out  
)
as

declare @mainColor char(3)

select @mainColor=MainColor
from Fl_Sessions
where Id=@Session_Id

if  exists(select 1
        from Fl_DeckDic dd1,Fl_DeckDic dd2 ,Fl_Tables t
        where ((dd1.color=dd2.color and dd2.val>dd1.val)
            or (dd2.color=@mainColor and dd1.color<>@mainColor)
              )
          and dd2.Id=@Card_Id
          and dd1.Id=t.Move_Card_Id
          and t.Session_Id=@Session_Id
          and t.Beat_Card_Id is null 
          )
begin
    update Fl_Tables
    set Beat_Card_Id=@Card_Id
    where Session_Id=@Session_Id
          and Beat_Card_Id is null 
          
    delete from Fl_Hands where Session_Id=@Session_Id and User_Id=@User_Id and Card_Id=@Card_Id   
        
    if 6=(select count(*) from Fl_Tables where Session_Id=@Session_Id)
        or 0=(select count(*) from Fl_Hands where Session_Id=@Session_Id and User_Id=@User_Id)
    begin
        insert  Fl_Actions  ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId,MoveUser_Id )   
        select top 1
         @Session_Id
        ,u1.Users_ShortName + ' бьется '+d.pic+' '+d.color+'. Oтбой. '
        ,a.Beat_UserId
        ,getdate()
        ,a.FirstMove_UserId
        ,a.Beat_UserId
        ,a.MoveUser_Id
        from Fl_Actions a
            join kplus..Users u1 on u1.Users_Id= @User_Id
            join Fl_DeckDic d on d.Id=@Card_Id
        where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
        order by a.rdt desc
    
        delete from Fl_Tables where Session_Id=@Session_Id  
        select @Result='EndRound'
        return
    end
    
     
    
    insert  Fl_Actions   ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId ,MoveUser_Id )   
    select top 1
         @Session_Id
        ,u1.Users_ShortName + ' бьется '+d.pic+' '+d.color+'. Подкидывает '+u2.Users_ShortName
        ,a.MoveUser_Id
        ,getdate()
        ,a.FirstMove_UserId
        ,a.Beat_UserId
        ,a.MoveUser_Id
    from Fl_Actions a
        join kplus..Users u1 on u1.Users_Id= @User_Id
        join kplus..Users u2 on u2.Users_Id=a.MoveUser_Id
        join Fl_DeckDic d on d.Id=@Card_Id
    where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
    order by a.rdt desc
                   
     
end 

go


create procedure   Fl_ProcTAKE
(
      @Session_Id int
     ,@User_Id int   
)
as
           
insert  Fl_Actions  ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId ,MoveUser_Id,TakeFlag )   
select top 1
 @Session_Id
,u1.Users_ShortName + ' забирает'
,a.MoveUser_Id
,getdate()
,a.FirstMove_UserId
,a.Beat_UserId  
,a.MoveUser_Id
,'T'
from Fl_Actions a
    join kplus..Users u1 on u1.Users_Id= @User_Id
where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
order by a.rdt desc
 
go
   
create procedure   Fl_FillHands
(
      @Session_Id int
     ,@BeginUser_Id int   
     ,@BeatUser_Id int
)
as
declare @cnt int,@i int
    ,@NextUser_Id int
    ,@Card_Id int
    ,@j int

select @j=0
while @j<6
begin 
    select @cnt=6-Count(*)
    from Fl_Hands 
    where Session_Id=@Session_Id
        and User_Id=@BeginUser_Id
        
    select @i=0
    while @i<@cnt
    begin
        select @Card_Id=null
         exec Fl_GetCard @Session_Id ,@Card_Id out
         if @Card_Id is not null
             insert Fl_Hands                   select @Session_Id, @BeginUser_Id,@Card_Id
             
         select @i=@i+1
    end  
    
    exec Fl_NextUser @Session_Id, @BeginUser_Id, @BeatUser_Id, @NextUser_Id out
    
    select @BeginUser_Id=@NextUser_Id
    select @j=@j+1
end


select @i=0
select @cnt=6-Count(*)
    from Fl_Hands 
    where Session_Id=@Session_Id
        and User_Id=@BeatUser_Id
    while @i<@cnt
    begin
        select @Card_Id=null
         exec Fl_GetCard @Session_Id ,@Card_Id out
         
         if @Card_Id is not null
            insert Fl_Hands         select @Session_Id, @BeatUser_Id,@Card_Id
         select @i=@i+1
    end 

go

    
create   procedure   Fl_Start_UI
(
    @User_Id int
    ,@User2 int
    ,@User3 int
    ,@User4 int
    ,@User5 int
    ,@User6 int
)
as
declare @Session_Id int

create table #users(userid int null)
insert #users select  @User_Id 
insert #users select  @User2
insert #users select  @User3
insert #users select  @User4
insert #users select  @User5
insert #users select  @User6


if (select count(distinct userid) from #users where isnull(userid,0)<>0)<>(select count(*) from #users where isnull(userid,0)<>0)
begin
    select 'Choose different users'
    return
end


exec  Fl_Start 
     @User_Id 
    ,@User2 
    ,@User3 
    ,@User4 
    ,@User5 
    ,@User6
    ,@Session_Id out    

if @Session_Id>0    
    select  'Table '+cast(@Session_Id as varchar)+' created. DblClick to connect.',OnClickCmd_1 = 'MenuName:Connect^Default:Y^FormName:report.OpenReport^param.Reports_ShortName:FlConnect^param.ParamsSQL:SELECT ' + convert(varchar, @User_Id) 
 
else 
    select 'Error'       
go


create   procedure  Fl_Table_UI
(
    @User_Id int
)
as
declare @Session_Id int
    ,@i int 
    ,@o int 
    ,@ActUserId int  
    ,@BeatUserId int  

select @Session_Id=max(ss.Id) from Fl_Users u join Fl_Sessions ss on ss.Id=u.Session_Id and u.User_Id=@User_Id
where ss.BeginAt>dateadd(hour,-1,getdate()) and ss.Status='S'

if isnull(@Session_Id,0)=0
begin    
    select 'Table is not found. Start game using report FlStart'
    return
end  

select top 1 @ActUserId=a.NextAction_UserId  ,   @BeatUserId=a.Beat_UserId
from Fl_Actions a
where a.Session_Id=@Session_Id   
order by rdt desc 


create table #out
(
    Ord int identity
    ,CardsInHand varchar(10) null
    ,CardMovement varchar(10) null
    ,CardBeatOff varchar(10) null
    ,Deck varchar(30) null
    ,Log varchar(200) null
    ,Card_Id int null
    ,Action char(4) null 
    ,rdt datetime  null
    ,CardFmt varchar(100) null
    ,Users varchar(30) null
)


insert #out (Log,Card_Id,Action,rdt)
select txt,0,'N',rdt
from  Fl_Actions
where Session_Id=@Session_Id
order by rdt desc

while (select count(*) from  #out)<30
    insert #out (Card_Id,Action) select 0,'N'
    
  

select Ord=identity(8),CardsInHand=dd.color+' '+dd.pic
    ,Card_Id=dd.Id
    ,Action=case when @ActUserId=@User_Id 
                  then 
                    case when @ActUserId=@BeatUserId then 'BEAT'         
                    else 'MOVE' end 
                else null end 
into #hand
from Fl_Hands h join Fl_DeckDic dd on dd.Id=h.Card_Id where h.Session_Id=@Session_Id and h.User_Id=@User_Id


if @ActUserId=@User_Id and @User_Id<>@BeatUserId  and (select count(*) from Fl_Tables  t  where t.Session_Id=@Session_Id)>0
    insert #hand 
    select '<Пас>',0,'PASS' 

if @ActUserId=@User_Id and @User_Id=@BeatUserId  
    insert #hand
    select '<Беру>',0,'TAKE'    
    
  
update #out
set CardsInHand=h.CardsInHand
    ,Action=h.Action
    ,CardFmt=case when ss.Id is not null then  'Ваши карты:BG=FF0000;'
            else   case when @ActUserId=@User_Id then 'Ваши карты:BG=ABEBC6;' else null end 
            end
    ,Card_Id=h.Card_Id
from #hand h
    left join Fl_DeckDic dd on dd.Id=h.Card_Id
    left join Fl_Sessions ss on ss.MainColor=dd.color and ss.Id=@Session_Id
where   h.Ord= #out.Ord


select Ord=identity(8), ku.Users_ShortName+case when u.Status='W' then ' (вышел)' else '('+(select cast(Count(*) as varchar) from Fl_Hands where Session_Id=@Session_Id and User_Id=ku.Users_Id)+')' end   Users
into #users 
from kplus..Users ku join Fl_Users u on u.User_Id=ku.Users_Id
where u.Session_Id=@Session_Id
order by u.Ord
                      
                      
update #out
set Users=h.Users     
from #users h
where   h.Ord= #out.Ord                      

select @o=isnull(count(*),0) from Fl_Decks d where d.Session_Id= @Session_Id
update #out 
set Deck='Карт: '+cast(@o as varchar)
where Ord=1
    
select @o=isnull(max(Ord),0) from Fl_Decks d where d.Session_Id= @Session_Id
update #out 
set Deck='козырь: '+dd.color+' '+dd.pic 
from Fl_Decks h join Fl_DeckDic dd on dd.Id=h.Card_Id
where #out.Ord=2
    and h.Session_Id =@Session_Id
    and h.Ord=@o
    
select Ord=identity(8),dd.color+' '+dd.pic Move ,dd2.color+' '+dd2.pic Beat   
into #table    
from Fl_Tables  t 
    join Fl_DeckDic dd on dd.Id=t.Move_Card_Id
    left join Fl_DeckDic dd2 on dd2.Id=t.Beat_Card_Id  
where t.Session_Id=@Session_Id 

update #out
set CardMovement=t.Move
    ,CardBeatOff=t.Beat
    
from #table t
where   t.Ord= #out.Ord    
 
 
select __TITLE__='Table ' +cast(@Session_Id as varchar) 
    ,__R_AUTO_REFRESH_SUBJECT__='RADIUS.FUN.FL.'+cast(@Session_Id as varchar)   

select 
    CardsInHand  'Ваши карты'
    ,CardMovement  'Подкинули'
    ,CardBeatOff     'Побили'
    ,Deck              'Колода'
    ,Log  
    ,convert(varchar,rdt,8) as TimeStep 
    ,Users 
    ,OnClickCmd_1 = case when @ActUserId=@User_Id then 'MenuName:DblClick^Default:Y^FormName:report.OpenReport^param.Reports_ShortName:FlAction^param.ParamsSQL:SELECT ' 
       + convert(varchar, @Session_Id)
        +','+ convert(varchar, @User_Id)
        +','''+Action
        +''','+convert(varchar,Card_Id )         
        else '' end
     ,CardFmt '$fmt$' 
from #out order by Ord


drop table #out


go 

create procedure Fl_Action_UI
(
     @Session_Id int
     ,@User_Id int
     ,@Action char(4)
     ,@Card_Id int
)
as  
declare @Result varchar(10)
    ,@FirstUser_Id int
    ,@BeatUser_Id int
    ,@NextUser_Id int
    ,@ExUser_Id int
    ,@TakeFlag char(1)

select top 1
         @FirstUser_Id=a.FirstMove_UserId
         ,@BeatUser_Id=a.Beat_UserId
         , @ExUser_Id=0
         ,@TakeFlag=a.TakeFlag
    from Fl_Actions a
    where  Session_Id=@Session_Id  and NextAction_UserId=@User_Id
    order by a.rdt desc

if @Action='MOVE'
begin
    exec Fl_ProcMOVE   @Session_Id, @User_Id, @Card_Id
end

if @Action='BEAT'
begin
    exec Fl_ProcBEAT  @Session_Id, @User_Id,@Card_Id, @Result out
end

if @Action='PASS'
begin
    exec Fl_ProcPASS   @Session_Id, @User_Id , @Result out
end

if @Action='TAKE'
begin
    exec Fl_ProcTAKE  @Session_Id, @User_Id
end

if @Result= 'EndRound'
begin      
    if @TakeFlag='T'
    begin
        select @ExUser_Id=@BeatUser_Id
    
          insert Fl_Hands
        select  @Session_Id, @BeatUser_Id,Move_Card_Id
        from Fl_Tables
        where Session_Id=@Session_Id
        
        insert Fl_Hands
        select  @Session_Id, @BeatUser_Id,Beat_Card_Id
        from Fl_Tables
        where Session_Id=@Session_Id
            and Beat_Card_Id is not null
    end            
    
    delete from Fl_Tables where Session_Id=@Session_Id     
    
    
    exec Fl_FillHands @Session_Id,@FirstUser_Id,@BeatUser_Id
    
    update Fl_Users
    set Status='Q'
    where Session_Id=@Session_Id
        and User_Id not in (select User_Id             
                from Fl_Hands h
                where h.Session_Id=@Session_Id
                )
        and Status not in ('W')
     
    insert  Fl_Actions    ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId ,MoveUser_Id ,TakeFlag)   
    select 
         @Session_Id
        ,u1.Users_ShortName + ' вышел. '
        ,a.MoveUser_Id
        ,getdate()
        ,a.FirstMove_UserId
        ,a.Beat_UserId
        ,a.MoveUser_Id
        ,a.TakeFlag
    from Fl_Actions a        
        join Fl_Users u on u.Session_Id=a.Session_Id 
        join kplus..Users u1 on u1.Users_Id= u.User_Id        
    where  a.Session_Id=@Session_Id 
        and u.Status='Q'
        and a.rdt=(select max(rdt) from Fl_Actions where Session_Id=@Session_Id)
    
    
    update Fl_Users
    set Status='W'
    where Session_Id=@Session_Id
        and User_Id not in (select User_Id             
                from Fl_Hands h
                where h.Session_Id=@Session_Id
                )                     
                    
                             
                
    if 2>(select count(*) from Fl_Users where Session_Id = @Session_Id  and Status not in ('W'))
        begin
             insert  Fl_Actions  ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId ,MoveUser_Id )  
            select  top 1
                 @Session_Id
                ,'Игра окончена. Остался '+u1.Users_ShortName + '. '
                ,0
                ,getdate()
                ,a.FirstMove_UserId
                ,a.Beat_UserId
                ,a.MoveUser_Id
            from Fl_Actions a 
                join kplus..Users u1 on u1.Users_Id=a.Beat_UserId       
            where  Session_Id=@Session_Id 
            order by a.rdt desc  
        end
        else begin
        
           exec Fl_NextUser      @Session_Id    ,@FirstUser_Id    ,@ExUser_Id  ,@NextUser_Id  out   
           
           exec Fl_NextUser      @Session_Id    ,@NextUser_Id    ,0  ,@BeatUser_Id  out
           
           
             insert  Fl_Actions   ( Session_Id  ,txt ,NextAction_UserId   ,rdt,FirstMove_UserId,Beat_UserId ,MoveUser_Id )  
            select  
                 @Session_Id
                ,'Ходит '+u1.Users_ShortName
                ,@NextUser_Id
                ,getdate()
                ,@NextUser_Id
                ,@BeatUser_Id
                ,@NextUser_Id
             from kplus..Users  u1
             where u1.Users_Id=@NextUser_Id
  
        
        end         
         
    
end

select 'Отодвиньте это окно в сторону, не закрывайте'   

insert into Kustom..RadiusJongleur 
select 'S', getdate(), null, null, null, null, 'N', 'RADIUS.FUN.FL.'+cast(@Session_Id as varchar), '', 0 , 'N' 
exec Kustom..sp_Jongleur_Notify

return
go  




-- Open report FlConnect

--/////////////////////////////////////////////////////////////
--// Open Report - 'FlConnect'
DECLARE @Reports_Id int, @ReportsParameters_Id int, @ParamOrder int, @RadiusReportsFolders_Id int, @ExtParamSQL nvarchar(16384)
SELECT @Reports_Id = Reports_Id FROM Reports WHERE Reports_ShortName = 'FlConnect'
IF @Reports_Id IS NULL
BEGIN
   --// allocate @Reports_Id
   update KustomIdServer set KustomId = KustomId + 1, @Reports_Id = KustomId + 1

   INSERT INTO Reports
      (Reports_Id,Reports_ShortName, Reports_Name, Reports_Object, Reports_ObjectLocation, Reports_InBaseFrame)
   Values
      (@Reports_Id,'FlConnect','FlConnect','Fl_Table_UI',0,'N' )

   if isnull('','') != '' or isnull('','') != ''
   begin
      select @RadiusReportsFolders_Id =  RadiusReportsFolders_Id from RadiusReportsFolders where RadiusReportsFolders_ShortName = ''

      if isnull(@RadiusReportsFolders_Id,0) = 0 and '' != ''
      begin
         insert RadiusReportsFolders (RadiusReportsFolders_ShortName, RadiusReportsFolders_Name) values ('', '')
         select RadiusReportsFolders_Id = @@IDENTITY
      end

      insert RadiusReportsParams ( Reports_Id, RadiusReportsFolders_Id, ResultsMode, ResultsAggregation, ClickToActivate, ExternalDbSubject)
      values (@Reports_Id, @RadiusReportsFolders_Id, 'C', 'N', 'Y', '')
   end
END
ELSE
BEGIN
   if object_id('RadiusReportsParametersExt') is not null
   begin
      exec(N'DELETE FROM RadiusReportsParametersExt
            WHERE ReportsParameters_Id in (select ReportsParameters_Id from ReportsParameters where Reports_Id = @Reports_Id)')


   end

   DELETE FROM ReportsParameters
   WHERE Reports_Id = @Reports_Id

   UPDATE Reports SET
      Reports_ShortName = 'FlConnect',
      Reports_Name      = 'FlConnect',
      Reports_Object    = 'Fl_Table_UI',
      Reports_ObjectLocation = 0,
      Reports_InBaseFrame = 'N'
   WHERE Reports_Id = @Reports_Id

   if isnull('','') != '' or isnull('','') != ''
   begin
      select @RadiusReportsFolders_Id =  RadiusReportsFolders_Id from RadiusReportsFolders where RadiusReportsFolders_ShortName = ''

      if isnull(@RadiusReportsFolders_Id,0) = 0 and '' != ''
      begin
         insert RadiusReportsFolders (RadiusReportsFolders_ShortName, RadiusReportsFolders_Name) values ('', '')
         select RadiusReportsFolders_Id = @@IDENTITY
      end

      update RadiusReportsParams set
         RadiusReportsFolders_Id = isnull(RadiusReportsFolders_Id, @RadiusReportsFolders_Id), -- настроенные группы не апдейтим
         ExternalDbSubject = isnull(ExternalDbSubject,'')
      where Reports_Id = @Reports_Id

      -- если параметры отчета только что добавились
      if @@rowcount = 0
         insert RadiusReportsParams ( Reports_Id, RadiusReportsFolders_Id, ResultsMode, ResultsAggregation, ClickToActivate, ExternalDbSubject)
         values (@Reports_Id, @RadiusReportsFolders_Id, 'C', 'N', 'Y', '')
   end
END
   SELECT @ParamOrder = 0
   
   
 
--/////////////////////////////////////////////////////////////
--// Open Report Parameters - 'FlConnect'

-- Parameters for FlConnect

if (0 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim(''))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, '##USER',       0,        @Reports_Id, 0,        0,      rtrim(''),  0,       rtrim(''), rtrim(''),            rtrim(''),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''N''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end

go
-- Open report FlStart

--/////////////////////////////////////////////////////////////
--// Open Report - 'FlStart'
DECLARE @Reports_Id int, @ReportsParameters_Id int, @ParamOrder int, @RadiusReportsFolders_Id int, @ExtParamSQL nvarchar(16384)
SELECT @Reports_Id = Reports_Id FROM Reports WHERE Reports_ShortName = 'FlStart'
IF @Reports_Id IS NULL
BEGIN
   --// allocate @Reports_Id
   update KustomIdServer set KustomId = KustomId + 1, @Reports_Id = KustomId + 1

   INSERT INTO Reports
      (Reports_Id,Reports_ShortName, Reports_Name, Reports_Object, Reports_ObjectLocation, Reports_InBaseFrame)
   Values
      (@Reports_Id,'FlStart','FlStart','Fl_Start_UI',0,'N' )

   if isnull('','') != '' or isnull('','') != ''
   begin
      select @RadiusReportsFolders_Id =  RadiusReportsFolders_Id from RadiusReportsFolders where RadiusReportsFolders_ShortName = ''

      if isnull(@RadiusReportsFolders_Id,0) = 0 and '' != ''
      begin
         insert RadiusReportsFolders (RadiusReportsFolders_ShortName, RadiusReportsFolders_Name) values ('', '')
         select RadiusReportsFolders_Id = @@IDENTITY
      end

      insert RadiusReportsParams ( Reports_Id, RadiusReportsFolders_Id, ResultsMode, ResultsAggregation, ClickToActivate, ExternalDbSubject)
      values (@Reports_Id, @RadiusReportsFolders_Id, 'C', 'N', 'Y', '')
   end
END
ELSE
BEGIN
   if object_id('RadiusReportsParametersExt') is not null
   begin
      exec(N'DELETE FROM RadiusReportsParametersExt
            WHERE ReportsParameters_Id in (select ReportsParameters_Id from ReportsParameters where Reports_Id = @Reports_Id)')


   end

   DELETE FROM ReportsParameters
   WHERE Reports_Id = @Reports_Id

   UPDATE Reports SET
      Reports_ShortName = 'FlStart',
      Reports_Name      = 'FlStart',
      Reports_Object    = 'Fl_Start_UI',
      Reports_ObjectLocation = 0,
      Reports_InBaseFrame = 'N'
   WHERE Reports_Id = @Reports_Id

   if isnull('','') != '' or isnull('','') != ''
   begin
      select @RadiusReportsFolders_Id =  RadiusReportsFolders_Id from RadiusReportsFolders where RadiusReportsFolders_ShortName = ''

      if isnull(@RadiusReportsFolders_Id,0) = 0 and '' != ''
      begin
         insert RadiusReportsFolders (RadiusReportsFolders_ShortName, RadiusReportsFolders_Name) values ('', '')
         select RadiusReportsFolders_Id = @@IDENTITY
      end

      update RadiusReportsParams set
         RadiusReportsFolders_Id = isnull(RadiusReportsFolders_Id, @RadiusReportsFolders_Id), -- настроенные группы не апдейтим
         ExternalDbSubject = isnull(ExternalDbSubject,'')
      where Reports_Id = @Reports_Id

   
      if @@rowcount = 0
         insert RadiusReportsParams ( Reports_Id, RadiusReportsFolders_Id, ResultsMode, ResultsAggregation, ClickToActivate, ExternalDbSubject)
         values (@Reports_Id, @RadiusReportsFolders_Id, 'C', 'N', 'Y', '')
   end
END
   SELECT @ParamOrder = 0
   
  
--/////////////////////////////////////////////////////////////
--// Open Report Parameters - 'FlStart'

-- Parameters for FlStart

if (0 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim(''))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, '##USER',       0,        @Reports_Id, 0,        0,      rtrim(''),  0,       rtrim(''), rtrim(''),            rtrim(''),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''N''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end


if (1 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim('kplus..Users'))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [kplus..Users] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, 'User2',       0,        @Reports_Id, 0,        0,      rtrim(''),  1,       rtrim('kplus..Users'), rtrim('Users_ShortName'),            rtrim('Users_Id'),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''N''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end


if (1 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim('kplus..Users'))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [kplus..Users] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, 'User3',       0,        @Reports_Id, 1,        0,      rtrim(''),  1,       rtrim('kplus..Users'), rtrim('Users_ShortName'),            rtrim('Users_Id'),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''N''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end


if (1 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim('kplus..Users'))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [kplus..Users] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, 'User4',       0,        @Reports_Id, 1,        0,      rtrim(''),  1,       rtrim('kplus..Users'), rtrim('Users_ShortName'),            rtrim('Users_Id'),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''N''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end


if (1 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim('kplus..Users'))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [kplus..Users] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, 'User5',       0,        @Reports_Id, 1,        0,      rtrim(''),  1,       rtrim('kplus..Users'), rtrim('Users_ShortName'),            rtrim('Users_Id'),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''N''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end


if (1 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim('kplus..Users'))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [kplus..Users] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, 'User6',       0,        @Reports_Id, 1,        0,      rtrim(''),  1,       rtrim('kplus..Users'), rtrim('Users_ShortName'),            rtrim('Users_Id'),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''N''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end

go
-- Open report FlAction

--/////////////////////////////////////////////////////////////
--// Open Report - 'FlAction'
DECLARE @Reports_Id int, @ReportsParameters_Id int, @ParamOrder int, @RadiusReportsFolders_Id int, @ExtParamSQL nvarchar(16384)
SELECT @Reports_Id = Reports_Id FROM Reports WHERE Reports_ShortName = 'FlAction'
IF @Reports_Id IS NULL
BEGIN
   --// allocate @Reports_Id
   update KustomIdServer set KustomId = KustomId + 1, @Reports_Id = KustomId + 1

   INSERT INTO Reports
      (Reports_Id,Reports_ShortName, Reports_Name, Reports_Object, Reports_ObjectLocation, Reports_InBaseFrame)
   Values
      (@Reports_Id,'FlAction','FlAction','Fl_Action_UI',0,'N' )

   if isnull('','') != '' or isnull('','') != ''
   begin
      select @RadiusReportsFolders_Id =  RadiusReportsFolders_Id from RadiusReportsFolders where RadiusReportsFolders_ShortName = ''

      if isnull(@RadiusReportsFolders_Id,0) = 0 and '' != ''
      begin
         insert RadiusReportsFolders (RadiusReportsFolders_ShortName, RadiusReportsFolders_Name) values ('', '')
         select RadiusReportsFolders_Id = @@IDENTITY
      end

      insert RadiusReportsParams ( Reports_Id, RadiusReportsFolders_Id, ResultsMode, ResultsAggregation, ClickToActivate, ExternalDbSubject)
      values (@Reports_Id, @RadiusReportsFolders_Id, 'C', 'N', 'Y', '')
   end
END
ELSE
BEGIN
   if object_id('RadiusReportsParametersExt') is not null
   begin
      exec(N'DELETE FROM RadiusReportsParametersExt
            WHERE ReportsParameters_Id in (select ReportsParameters_Id from ReportsParameters where Reports_Id = @Reports_Id)')


   end

   DELETE FROM ReportsParameters
   WHERE Reports_Id = @Reports_Id

   UPDATE Reports SET
      Reports_ShortName = 'FlAction',
      Reports_Name      = 'FlAction',
      Reports_Object    = 'Fl_Action_UI',
      Reports_ObjectLocation = 0,
      Reports_InBaseFrame = 'N'
   WHERE Reports_Id = @Reports_Id

   if isnull('','') != '' or isnull('','') != ''
   begin
      select @RadiusReportsFolders_Id =  RadiusReportsFolders_Id from RadiusReportsFolders where RadiusReportsFolders_ShortName = ''

      if isnull(@RadiusReportsFolders_Id,0) = 0 and '' != ''
      begin
         insert RadiusReportsFolders (RadiusReportsFolders_ShortName, RadiusReportsFolders_Name) values ('', '')
         select RadiusReportsFolders_Id = @@IDENTITY
      end

      update RadiusReportsParams set
         RadiusReportsFolders_Id = isnull(RadiusReportsFolders_Id, @RadiusReportsFolders_Id), -- настроенные группы не апдейтим
         ExternalDbSubject = isnull(ExternalDbSubject,'')
      where Reports_Id = @Reports_Id

      if @@rowcount = 0
         insert RadiusReportsParams ( Reports_Id, RadiusReportsFolders_Id, ResultsMode, ResultsAggregation, ClickToActivate, ExternalDbSubject)
         values (@Reports_Id, @RadiusReportsFolders_Id, 'C', 'N', 'Y', '')
   end
END
   SELECT @ParamOrder = 0
--/////////////////////////////////////////////////////////////
--// Open Report Parameters - 'FlAction'

-- Parameters for FlAction

if (0 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim(''))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, 'Session_Id',       0,        @Reports_Id, 0,        0,      rtrim(''),  0,       rtrim(''), rtrim(''),            rtrim(''),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end


if (0 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim(''))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, 'User_Id',       0,        @Reports_Id, 0,        0,      rtrim(''),  0,       rtrim(''), rtrim(''),            rtrim(''),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end


if (0 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim(''))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, 'Action',       3,        @Reports_Id, 0,        0,      rtrim(''),  0,       rtrim(''), rtrim(''),            rtrim(''),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''N''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end


if (0 = 2 and not exists(select 1 from KustomChoices where KustomChoices_Name = rtrim(''))  and 'K' = 'U')
   print 'WARNING!! KustomChoice: [] does not exists'
update KustomIdServer
   set KustomId = KustomId + 1,
   @ReportsParameters_Id = KustomId + 1
INSERT INTO ReportsParameters
   (ReportsParameters_Id,  ParamOrder,  ParamLabel, ParamType, Reports_Id,  AllowNULL, IsUpper, DefaultValue, ItemType, Source,      HelpList_DisplayColumn, HelpList_JoinColumn, HelpList_Interpose, HelpList_InterposeWhen, Choices_Type, Choices_Retreive, Choices_Display)
VALUES
   (@ReportsParameters_Id, @ParamOrder, 'Card_Id',       0,        @Reports_Id, 0,        0,      rtrim(''),  0,       rtrim(''), rtrim(''),            rtrim(''),         rtrim(''),       rtrim('F'),           rtrim('E'), rtrim('K'),     rtrim('B'))

SELECT @ParamOrder = @ParamOrder + 1

if object_id('RadiusReportsParametersExt') is not null
begin
   select @ExtParamSQL = '
      INSERT INTO RadiusReportsParametersExt
         (ReportsParameters_Id,  GroupLabelName, LineBackColor, PositionPrevLine, PositionLeft,              PositionLengths, CaptionSource, Style,        Tooltip,     Tag,         DetailsLabel,    DetailsCmd)
      VALUES
         (@ReportsParameters_Id, rtrim(''''),    rtrim(''''),   rtrim(''''),      null, rtrim(''''),     rtrim(''''),   rtrim(''''),  rtrim(''''), rtrim(''''), rtrim(''''),    rtrim(''''))
   '
   exec(@ExtParamSQL)


end

go
